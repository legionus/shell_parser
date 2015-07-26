#!/usr/bin/env perl

use strict;
use warnings;

use IO::String;

use ShellParser;
use ShellParser::Indent;

sub dump_lexeme {
	my ($context, $indent, $token) = @_;
	return $token->as_string();
}

sub dump_word {
	my ($context, $indent, $token) = @_;

	my $childs = [ map { print_token($context, $indent+0, $_) } @{$token->{value}} ];
	return join('', @{$childs});
}

sub _purge_heredoc {
	my ($context, $indent) = @_;

	return "" if !@{$context->{heredoc}};

	my $childs = [];
	while (my $heredoc = shift @{$context->{heredoc}}) {
		push(@{$childs}, $heredoc->{value} . $heredoc->{here_end});
	}

	return join("\n", @{$childs});
}

sub dump_list {
	my ($context, $indent, $token) = @_;
	my $delim = "\n";

	my $childs = [];
	foreach my $elem (@{$token->{body}}) {
		next if $elem->{body} && ref($elem->{body}) eq "ARRAY" && !@{$elem->{body}};
		push(@{$childs}, print_token($context, $indent+0, $elem));
	}

	return join($delim, @{$childs});
}

sub dump_andorlist {
	my ($context, $indent, $token) = @_;
	my $delim = "\n";
	my $child_indent = $indent->clone();

	my $childs = [];
	foreach my $elem (@{$token->{body}}) {
		next if $elem->{body} && ref($elem->{body}) eq "ARRAY" && !@{$elem->{body}};

		my $type = ref($elem);
		if ($type =~ /.*::Operator$/) {
			$childs->[-1] .= " " . print_token($context, $child_indent+0, $elem);
			next;
		}

		my $depth = 0;
		$depth += 1 if @{$childs} && $type !~ /^.*::Comments$/;

		my $indent_string = "";
		$indent_string .= $indent + $depth
			if !@{$context->{heredoc}} && $type !~ /^.*::Comments$/;

		push(@{$childs}, $indent_string . print_token($context, $child_indent+$depth, $elem));
	}

	my $sep = "";
	if ($token->{sep} ne "" && $token->{sep} ne ";") {
		$sep = " " . $token->{sep};
	}

	my $s = join($delim, @{$childs}) . $sep;

	if (@{$childs} > 0) {
		my $heredoc_str = _purge_heredoc($context, $indent+0);
		$s .= "\n$heredoc_str" if $heredoc_str;
	}

	return $s;
}

sub dump_pipeline {
	my ($context, $indent, $token) = @_;
	my $pipe_indent = $indent->clone();

	my $childs = [];
	foreach my $elem (@{$token->{body}}) {
		next if $elem->{body} && ref($elem->{body}) eq "ARRAY" && !@{$elem->{body}};

		my $s = "";
		$s .= " |" if @{$childs};

		my $heredoc_str = _purge_heredoc($context, $indent+0);
		if ($heredoc_str) {
			$s .= "\n" if @{$childs};
			$s .= "$heredoc_str\n";
		} else {
			$s .= " " if @{$childs};
		}

		$s .= print_token($context, $pipe_indent+0, $elem);

		push(@{$childs}, $s);
	}

	return ($token->{banged} ? "! " : "") . join("", @{$childs});
}

sub dump_comments {
	my ($context, $indent, $token) = @_;
	my $delim = "\n";

	my $childs = [];
	foreach my $elem (@{$token->{body}}) {
		next if $elem->{body} && ref($elem->{body}) eq "ARRAY" && !@{$elem->{body}};
		push(@{$childs}, $indent . print_token($context, $indent+0, $elem));
	}
	my $s = join($delim, @{$childs});

	return $s;
}

sub dump_commentedtoken {
	my ($context, $indent, $token) = @_;

	my $token_indent = $indent->clone();
	$token_indent->{depth} = 0;

	my $s = print_token($context, $token_indent, $token->{token});
	$s .= " " . print_token($context, $token_indent, $token->{comments})
		if $token->{comments} && @{$token->{comments}->{body}};

	return $s;
}

sub dump_redirection {
	my ($context, $indent, $token) = @_;

	my $redirection_indent = $indent->clone();
	$redirection_indent->{depth} = 0;

	return ($token->{left} // "") .
		$token->{redirection} .
		print_token($context, $redirection_indent, $token->{filename});
}

sub dump_simplecommand {
	my ($context, $indent, $token) = @_;

	my $prefix = [ map { print_token($context, $indent+0, $_) } @{$token->{prefix}} ];
	my $args   = [ map { print_token($context, $indent+0, $_) } @{$token->{args}}   ];

	my @cmd;
	push(@cmd, join(" ", @{$prefix}))                            if @{$prefix};
	push(@cmd, print_token($context, $indent+0, $token->{name})) if $token->{name};
	push(@cmd, join(" ", @{$args}))                              if @{$args};

	my $s = join(" ", @cmd);

	return $s;
}

sub dump_compoundcommand {
	my ($context, $indent, $token) = @_;
	my $childs = [ print_token($context, $indent+0, $token->{body}) ];

	foreach my $elem (@{$token->{redirect}}) {
		push(@{$childs}, print_token($context, $indent+0, $elem));
	}

	my $s = join(" ", @{$childs});

	return $s;
}

sub _complex_condition {
	my ($token) = @_;

	my $num_childs = 0;

	foreach my $child (@{$token->{body}}) {
		$num_childs++ if $child->{body} && @{$child->{body}} > 0;
	}

	return ($num_childs > 1);
}

sub dump_condition {
	my ($context, $indent, $token) = @_;
	my $cond_indent = $indent->clone();

	if (_complex_condition($token)) {
		$cond_indent++;
	} else {
		$cond_indent->{depth} = 0;
	}

	return print_token($context, $cond_indent, $token);
}

sub dump_if {
	my ($context, $indent, $token) = @_;
	my $childs = [];
	foreach my $body (@{$token->{body}}) {
		if ($body->{condition}) {
			my $delim = " ";
			my $suffix = ";";

			if (_complex_condition($body->{condition})) {
				$delim = "\n";
				$suffix = "";
			}

			my $condition = [];
			push(@{$condition}, (!@{$childs} ? "if" : $indent . "elif"));
			push(@{$condition}, dump_condition($context, $indent, $body->{condition}) . $suffix);
			push(@{$condition}, "then");

			push(@{$childs}, join($delim, @{$condition}));
			push(@{$childs}, _purge_heredoc($context, $indent+0))
				if @{$context->{heredoc}};
		}
		else {
			push(@{$childs}, $indent . "else");
		}

		push(@{$childs}, print_token($context, $indent+1, $body->{body}));
	}
	push(@{$childs}, $indent . "fi");
	return join("\n", @{$childs});
}

sub dump_for {
	my ($context, $indent, $token) = @_;
	my $childs = [ "for" ];

	my $var_indent = $indent->clone();
	$var_indent->{depth} = 0;

	push(@{$childs}, print_token($context, $var_indent, $token->{variable}));

	my $words_indent = $indent->clone();
	$words_indent->{depth} = 0;

	my $words = [ map { print_token($context, $words_indent, $_) } @{$token->{words}} ];
	if (@{$words}) {
		push(@{$childs}, "in");
		push(@{$childs}, join(" ", @{$words}) . ";");
	} else {
		$childs->[-1] .= ";";
	}

	push(@{$childs}, print_token($context, $indent+0, $token->{body}));
	return join(" ", @{$childs});
}

sub dump_while {
	my ($context, $indent, $token) = @_;

	my $delim = " ";
	my $suffix = ";";

	if (_complex_condition($token->{condition})) {
		$delim = "\n";
		$suffix = "";
	}

	my $childs = [ "while" ];
	push(@{$childs}, dump_condition($context, $indent, $token->{condition}) . $suffix);
	push(@{$childs}, print_token($context, $indent+0, $token->{body}));
	return join($delim, @{$childs});
}

sub dump_until {
	my ($context, $indent, $token) = @_;

	my $delim = " ";
	my $suffix = ";";

	if (_complex_condition($token->{condition})) {
		$delim = "\n";
		$suffix = "";
	}

	my $childs = [ "until" ];
	push(@{$childs}, dump_condition($context, $indent, $token->{condition}) . $suffix);
	push(@{$childs}, print_token($context, $indent+0, $token->{body}));
	return join($delim, @{$childs});
}

sub dump_dogroup {
	my ($context, $indent, $token) = @_;
	my $childs = [];
	push(@{$childs}, "do");

	push(@{$childs}, _purge_heredoc($context, $indent+0))
		if @{$context->{heredoc}};

	push(@{$childs}, print_token($context, $indent+1, $token->{body}));
	push(@{$childs}, $indent . "done");
	return join("\n", @{$childs});
}

sub dump_case {
	my ($context, $indent, $token) = @_;
	my $childs = [];

	my $var_indent = $indent->clone();
	$var_indent->{depth} = 0;

	push(@{$childs}, "case " . print_token($context, $var_indent, $token->{word}) . " in");
	foreach my $item (@{$token->{items}}) {
		push(@{$childs}, print_token($context, $indent+1, $item));
	}
	push(@{$childs}, $indent . "esac");

	return join("\n", @{$childs});
}

sub dump_caseitem {
	my ($context, $indent, $token) = @_;
	my $childs   = [];
	my $patterns = [];

	foreach my $pattern (@{$token->{pattern}}) {
		my $pattern_indent = $indent->clone();
		$pattern_indent->{depth} = 0;

		push(@{$patterns}, "|")
			if @{$patterns};
		push(@{$patterns}, print_token($context, $pattern_indent, $pattern));
	}

	push(@{$childs}, $indent . "(" .  join("", @{$patterns}) . ")");

	push(@{$childs}, print_token($context, $indent+1, $token->{body}))
		if $token->{body};

	push(@{$childs}, ($indent+1) . ";;");

	return join("\n", @{$childs});
}

sub dump_bracegroup {
	my ($context, $indent, $token) = @_;
	my $childs = [];
	push(@{$childs}, "{");
	push(@{$childs}, print_token($context, $indent+1, $token->{body}));
	push(@{$childs}, $indent . "}");
	return join("\n", @{$childs});
}

sub dump_funcdef {
	my ($context, $indent, $token) = @_;
	my $childs = [];

	my $name_indent = $indent->clone();
	$name_indent->{depth} = 0;

	my $body = print_token($context, $indent+0, $token->{body});
	$body .= " " . print_token($context, $indent+0, $_) foreach @{$token->{redirect}};

	push(@{$childs}, print_token($context, $name_indent, $token->{name}) . '()');
	push(@{$childs}, $body);
	return join("\n", @{$childs});
}

sub dump_heredoc {
	my ($context, $indent, $token) = @_;
	my $childs = [];

	my $heredoc_indent = $indent->clone();
	$heredoc_indent->{depth} = 0;

	push(@$childs, $token->{type} . $token->{here_end}->raw_string());

	push(@{$context->{heredoc}}, {
		value    => join("", map { $_->raw_string() . "\n" } @{$token->{lines}}),
		here_end => $token->{here_end}->dequote(),
	});

	return join("\n", @{$childs});
}

sub dump_subshell {
	my ($context, $indent, $token) = @_;

	my $childs = [ '(' ];
	my $delim = "";
	my $complex = _complex_condition($token->{body});

	my $subshell_indent = $indent->clone();
	if (!$complex) {
		$subshell_indent->{depth} = 0;
		push(@{$childs}, print_token($context, $subshell_indent, $token->{body}));
		push(@{$childs}, ')');
	} else {
		$delim = "\n";
		$subshell_indent++;
		push(@{$childs}, print_token($context, $subshell_indent, $token->{body}));
		push(@{$childs}, $indent . ')');
	}

	return join($delim, @{$childs});
}

sub dump_commandsubstitution {
	my ($context, $indent, $token) = @_;

	my $childs = [];
	my $delim = "";
	my $complex = _complex_condition($token->{body});

	my $subshell_indent = $indent->clone();

	if ($complex) {
		$delim = "\n";
		$subshell_indent++;

		push(@{$childs}, '"$(');
		push(@{$childs}, print_token($context, $subshell_indent, $token->{body}));
		push(@{$childs}, $indent . ')"');
	} else {
		$subshell_indent->{depth} = 0;

		push(@{$childs}, '"$(');
		push(@{$childs}, print_token($context, $subshell_indent, $token->{body}));
		push(@{$childs}, ')"');
	}

	return join($delim, @{$childs});
}

my $dumper = {
	Lexeme              => \&dump_lexeme,
	QString             => \&dump_lexeme,
	QQString            => \&dump_lexeme,
	LineConcat          => \&dump_lexeme,
	Escaped             => \&dump_lexeme,
	Comment             => \&dump_lexeme,
	Operator            => \&dump_lexeme,
	Word                => \&dump_word,
	List                => \&dump_list,
	AndOrList           => \&dump_andorlist,
	Pipeline            => \&dump_pipeline,
	SimpleCommand       => \&dump_simplecommand,
	CompoundCommand     => \&dump_compoundcommand,
	If                  => \&dump_if,
	For                 => \&dump_for,
	DoGroup             => \&dump_dogroup,
	FuncDef             => \&dump_funcdef,
	BraceGroup          => \&dump_bracegroup,
	Case                => \&dump_case,
	CaseItem            => \&dump_caseitem,
	Redirection         => \&dump_redirection,
	While               => \&dump_while,
	Until               => \&dump_until,
	HereDoc             => \&dump_heredoc,
	SubShell            => \&dump_subshell,
	CommandSubstitution => \&dump_commandsubstitution,
	Comments            => \&dump_comments,
	CommentedToken      => \&dump_commentedtoken,
};

sub print_token {
	my ($context, $indent, $token) = @_;

	my $type = ref($token);
	$type =~ s/.*:://;

	my $func = $dumper->{$type} || 0;

	return $func->($context, $indent, $token) if $func;
	return "NOT-IMPLEMENTED ($type)";
}

sub parse_subshell {
	my ($token) = @_;
	my $type = ref($token);

	if ($type =~ /^.*::CommandSubstitution$/) {
		my $p = ShellParser->new();

		my $subshell = join('', map { $_->[1]->raw_string() } @{$token->{tokens}});
		my $io = IO::String->new($subshell);

		$token->{body} = $p->parse(sub { return scalar <$io>; });
		return $token->{body}->traverse(\&parse_subshell);
	}

	return $token->traverse(\&parse_subshell);
}

my $p = ShellParser->new();

open(my $fh, '<', $ARGV[0]) or die $!;

my $lineno = 0;
my $result = $p->parse(sub {
	$lineno++;
	return scalar <$fh>;
});

parse_subshell($result);

my $context = {
	heredoc => [],
};
print print_token($context, ShellParser::Indent->new(), $result) . "\n";
