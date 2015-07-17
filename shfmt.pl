#!/usr/bin/env perl

use strict;
use warnings;

use ShellParser;
use ShellParser::Indent;

sub dump_lexeme {
	my ($context, $indent, $token) = @_;
	return $token->as_string();
}

sub dump_list {
	my ($context, $indent, $token) = @_;

	my $childs = [ map { print_token($context, $indent+0, $_) } @{$token->{body}} ];
	my $delim = $indent->{condition} ? " " : "\n";

	my $s = "";
	if (!$indent->{condition}) {
		while (my $heredoc = shift @{$context->{heredoc}}) {
			$s .= "\n" . $heredoc->{value} . $heredoc->{here_end};
		}
	}

	return join($delim, @{$childs}) . $s;
}

sub dump_andorlist {
	my ($context, $indent, $token) = @_;
	my $delim = "\n";

	my $child_indent = $indent->clone();
	$child_indent->{heredoc_split} = 1 if @{$token->{rest}};

	my $childs = [ $indent . print_token($context, $child_indent+0, $token->{first}) ];

	my $indent_string = "";
	$indent_string .= $indent + 1 if !@{$context->{heredoc}};

	foreach my $elem (@{$token->{rest}}) {
		$childs->[-1] .= " " . ($elem->[0] // "");
		push(@{$childs}, $indent_string . print_token($context, $child_indent+0, $elem->[1]));
	}

	if ($indent->{condition} && $token->{sep} eq "\n") {
		$token->{sep} = ";";
	}

	my $sep = "";
	if ($token->{sep} ne "") {
		if ($token->{sep} eq ";") {
			$sep = $token->{sep};
		}
		elsif ($token->{sep} ne "\n") {
			$sep = " " . $token->{sep};
		}
	}

	if ($context->{andorlist_ignore_sep}) {
		$context->{andorlist_ignore_sep} = 0;
		$sep = "";
	}

	if (@{$context->{heredoc}} > 0) {
		$delim = " ";
	}

	my $s = join($delim, @{$childs}) . $sep;

	return $s;
}

sub dump_pipeline {
	my ($context, $indent, $token) = @_;

	my $pipe_indent = $indent->clone();
	if (@{$token->{body}} > 1) {
		$pipe_indent->{heredoc_split} = 1;
	}

	my $childs = [];
	foreach my $a (@{$token->{body}}) {
		my $tailing_space = ((@{$token->{body}} - @{$childs}) == 1 ? "" : " ");

		push(@$childs, print_token($context, $pipe_indent+0, $a) . $tailing_space);
		$pipe_indent->{depth} = 0;
	}

	my $s = ($token->{banged} ? "! " : "") . join("| ", @{$childs});
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

sub dump_condition {
	my ($context, $indent, $token) = @_;

	my $cond_indent = $indent->clone();
	$cond_indent->{condition}     = 1;
	$cond_indent->{heredoc_split} = 1;
	$cond_indent->{depth}         = 0;

	return print_token($context, $cond_indent, $token);
}

sub dump_if {
	my ($context, $indent, $token) = @_;
	my $childs = [];
	foreach my $body (@{$token->{body}}) {
		if ($body->{condition}) {
			my $condition = [
				(!@{$childs} ? "if" : $indent . "elif"),
				dump_condition($context, $indent, $body->{condition}),
				"then",
			];
			push(@{$childs}, join(" ", @{$condition}));

			while (my $heredoc = shift @{$context->{heredoc}}) {
				push(@{$childs}, $heredoc->{value} . $heredoc->{here_end});
			}

			push(@{$childs}, print_token($context, $indent+1, $body->{body}));
		}
		else {
			push(@{$childs}, $indent . "else");
			push(@{$childs}, print_token($context, $indent+1, $body->{body}));
		}
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
	}

	push(@{$childs}, print_token($context, $indent+0, $token->{body}));
	return join(" ", @{$childs});
}

sub dump_while {
	my ($context, $indent, $token) = @_;
	my $childs = [ "while" ];
	push(@{$childs}, dump_condition($context, $indent, $token->{condition}));
	push(@{$childs}, print_token($context, $indent+0, $token->{body}));
	return join(" ", @{$childs});
}

sub dump_until {
	my ($context, $indent, $token) = @_;
	my $childs = [ "until" ];
	push(@{$childs}, dump_condition($context, $indent, $token->{condition}));
	push(@{$childs}, print_token($context, $indent+0, $token->{body}));
	return join(" ", @{$childs});
}

sub dump_dogroup {
	my ($context, $indent, $token) = @_;
	my $childs = [];
	push(@{$childs}, "do");
	while (my $heredoc = shift @{$context->{heredoc}}) {
		push(@{$childs}, $heredoc->{value} . $heredoc->{here_end});
	}
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

	my @redir;
	foreach my $redirect (@{$token->{redirect}}) {
		push(@redir, print_token($context, $indent+0, $redirect));
	}

	my $body = print_token($context, $indent+0, $token->{body});
	$body .= " " . join(" ", @redir) if @redir;

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
	my $heredoc_value = join("", map { $_->raw_string() . "\n" } @{$token->{lines}});

	if ($indent->{heredoc_split}) {
		push(@{$context->{heredoc}}, {
			value    => $heredoc_value,
			here_end => $token->{here_end}->dequote(),
		});
	}
	else {
		$context->{andorlist_ignore_sep} = 1;
		push(@$childs, $heredoc_value . $token->{here_end}->dequote());
	}

	return join("\n", @{$childs});
}

my $dumper = {
	Lexeme          => \&dump_lexeme,
	Word            => \&dump_lexeme,
	QString         => \&dump_lexeme,
	QQString        => \&dump_lexeme,
	LineConcat      => \&dump_lexeme,
	List            => \&dump_list,
	AndOrList       => \&dump_andorlist,
	Pipeline        => \&dump_pipeline,
	SimpleCommand   => \&dump_simplecommand,
	CompoundCommand => \&dump_compoundcommand,
	If              => \&dump_if,
	For             => \&dump_for,
	DoGroup         => \&dump_dogroup,
	FuncDef         => \&dump_funcdef,
	BraceGroup      => \&dump_bracegroup,
	Case            => \&dump_case,
	CaseItem        => \&dump_caseitem,
	Redirection     => \&dump_redirection,
	While           => \&dump_while,
	Until           => \&dump_until,
	HereDoc         => \&dump_heredoc,
};

sub print_token {
	my ($context, $indent, $token) = @_;

	my $type = ref($token);
	$type =~ s/.*:://;

	my $func = $dumper->{$type} || 0;

	return $func->($context, $indent, $token) if $func;
	return "NOT-IMPLEMENTED ($type)";
}

my $p = ShellParser->new();

open(my $fh, '<', $ARGV[0]) or die $!;

my $lineno = 0;
my $result = $p->parse(sub {
	$lineno++;
	return scalar <$fh>;
});

my $context = {
	heredoc => [],
};
print print_token($context, ShellParser::Indent->new(), $result) . "\n";
