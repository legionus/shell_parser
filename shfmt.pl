#!/usr/bin/env perl

use strict;
use warnings;

use Switch;

use ShellParser;
use ShellParser::Indent;

sub dump_lexeme {
	my ($indent, $token) = @_;
	return $token->as_string();
}

sub dump_list {
	my ($indent, $token) = @_;

	my $childs = [ map { print_token($indent+0, $_) } @{$token->{body}} ];
	my $delim = $indent->{condition} ? " " : "\n";

	return join($delim, @{$childs});
}

sub dump_andorlist {
	my ($indent, $token) = @_;

	my $childs = [ $indent . print_token($indent+0, $token->{first}) ];

	foreach my $elem (@{$token->{rest}}) {
		$childs->[-1] .= " " . ($elem->[0] // "");
		push(@{$childs}, ($indent + 1) . print_token($indent+0, $elem->[1]));
	}

	my $delim = $indent->{condition} ? " " : "\n";

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

	my $s = join($delim, @{$childs}) . $sep;

	return $s;
}

sub dump_pipeline {
	my ($indent, $token) = @_;
	my $pipe_indent = $indent->clone();

	my $childs = [];
	foreach my $a (@{$token->{body}}) {
		my $tailing_space = ((@{$token->{body}} - @{$childs}) == 1 ? "" : " ");

		push(@$childs, print_token($pipe_indent+0, $a) . $tailing_space);
		$pipe_indent->{depth} = 0;
	}

	my $s = ($token->{banged} ? "! " : "") . join("| ", @{$childs});

	return $s;
}

sub dump_redirection {
	my ($indent, $token) = @_;

	my $redirection_indent = $indent->clone();
	$redirection_indent->{depth} = 0;

	return ($token->{left} // "") .
		$token->{redirection} .
		print_token($redirection_indent, $token->{filename});
}

sub dump_simplecommand {
	my ($indent, $token) = @_;

	my $prefix = [ map { print_token($indent+0, $_) } @{$token->{prefix}} ];
	my $args   = [ map { print_token($indent+0, $_) } @{$token->{args}}   ];

	my @cmd;
	push(@cmd, join(" ", @{$prefix}))                  if @{$prefix};
	push(@cmd, print_token($indent+0, $token->{name})) if $token->{name};
	push(@cmd, join(" ", @{$args}))                    if @{$args};

	my $s = join(" ", @cmd);
	return $s;
}

sub dump_compoundcommand {
	my ($indent, $token) = @_;
	my $childs = [ print_token($indent+0, $token->{body}) ];
	return join(" ", @{$childs});
}

sub dump_if {
	my ($indent, $token) = @_;
	my $childs = [];
	foreach my $body (@{$token->{body}}) {
		if ($body->{condition}) {
			my $cond_indent = $indent->clone();
			$cond_indent->{condition} = 1;
			$cond_indent->{depth} = 0;

			my $condition = [];
			push(@{$condition}, (!@{$childs} ? "if" : $indent . "elif"));
			push(@{$condition}, print_token($cond_indent, $body->{condition}));
			push(@{$condition}, "then");

			push(@{$childs}, join(" ", @{$condition}));
			push(@{$childs}, print_token($indent+1, $body->{body}));
		}
		else {
			push(@{$childs}, $indent . "else");
			push(@{$childs}, print_token($indent+1, $body->{body}));
		}
	}
	push(@{$childs}, $indent . "fi");
	return join("\n", @{$childs});
}

sub dump_for {
	my ($indent, $token) = @_;
	my $childs = [];

	my $var_indent = $indent->clone();
	$var_indent->{depth} = 0;

	push(@{$childs}, "for");
	push(@{$childs}, print_token($var_indent, $token->{variable}));

	my $words_indent = $indent->clone();
	$words_indent->{depth} = 0;

	my $words = [ map { print_token($words_indent, $_) } @{$token->{words}} ];
	if (@{$words}) {
		push(@{$childs}, "in");
		push(@{$childs}, join(" ", @{$words}) . ";");
	}

	push(@{$childs}, print_token($indent+0, $token->{body}));
	return join(" ", @{$childs});
}

sub dump_while {
	my ($indent, $token) = @_;
	my $childs = [];

	my $cond_indent = $indent->clone();
	$cond_indent->{condition} = 1;
	$cond_indent->{depth} = 0;

	push(@{$childs}, "while " . print_token($cond_indent, $token->{condition}));

	push(@{$childs}, print_token($indent+0, $token->{body}));
	return join("\n", @{$childs});
}

sub dump_until {
	my ($indent, $token) = @_;
	my $childs = [];

	my $cond_indent = $indent->clone();
	$cond_indent->{condition} = 1;
	$cond_indent->{depth} = 0;

	push(@{$childs}, "until " . print_token($cond_indent, $token->{condition}));

	push(@{$childs}, print_token($indent+0, $token->{body}));
	return join("\n", @{$childs});
}

sub dump_dogroup {
	my ($indent, $token) = @_;
	my $childs = [];
	push(@{$childs}, "do");
	push(@{$childs}, print_token($indent+1, $token->{body}));
	push(@{$childs}, $indent . "done");
	return join("\n", @{$childs});
}

sub dump_case {
	my ($indent, $token) = @_;
	my $childs = [];

	my $var_indent = $indent->clone();
	$var_indent->{depth} = 0;

	push(@{$childs}, "case " . print_token($var_indent, $token->{word}) . " in");
	foreach my $item (@{$token->{items}}) {
		push(@{$childs}, print_token($indent+1, $item));
	}
	push(@{$childs}, $indent . "esac");

	return join("\n", @{$childs});
}

sub dump_caseitem {
	my ($indent, $token) = @_;
	my $childs   = [];
	my $patterns = [];

	foreach my $pattern (@{$token->{pattern}}) {
		my $pattern_indent = $indent->clone();
		$pattern_indent->{depth} = 0;

		push(@{$patterns}, "|")
			if @{$patterns};
		push(@{$patterns}, print_token($pattern_indent, $pattern));
	}

	push(@{$childs}, $indent . "(" .  join("", @{$patterns}) . ")");

	push(@{$childs}, print_token($indent+1, $token->{body}))
		if $token->{body};

	push(@{$childs}, ($indent+1) . ";;");

	return join("\n", @{$childs});
}

sub dump_bracegroup {
	my ($indent, $token) = @_;
	my $childs = [];
	push(@{$childs}, "{");
	push(@{$childs}, print_token($indent+1, $token->{body}));
	push(@{$childs}, $indent . "}");
	return join("\n", @{$childs});
}

sub dump_funcdef {
	my ($indent, $token) = @_;
	my $childs = [];

	my $name_indent = $indent->clone();
	$name_indent->{depth} = 0;

	my @redir;
	foreach my $redirect (@{$token->{redirect}}) {
		push(@redir, print_token($indent+0, $redirect));
	}

	my $body = print_token($indent+0, $token->{body});
	$body .= " " . join(" ", @redir) if @redir;

	push(@{$childs}, print_token($name_indent, $token->{name}) . '()');
	push(@{$childs}, $body);
	return join("\n", @{$childs});
}


sub print_token {
	my ($indent, $token) = @_;

	my $type = ref($token);
	$type =~ s/.*:://;

	switch ($type) {
		case /^(Lexeme|Word|QString|QQString|LineConcat)$/ {
		                         return dump_lexeme($indent, $token);          }
		case "List"            { return dump_list($indent, $token);            }
		case "AndOrList"       { return dump_andorlist($indent, $token);       }
		case "Pipeline"        { return dump_pipeline($indent, $token);        }
		case "SimpleCommand"   { return dump_simplecommand($indent, $token);   }
		case "CompoundCommand" { return dump_compoundcommand($indent, $token); }
		case "If"              { return dump_if($indent, $token);              }
		case "For"             { return dump_for($indent, $token);             }
		case "DoGroup"         { return dump_dogroup($indent, $token);         }
		case "FuncDef"         { return dump_funcdef($indent, $token);         }
		case "BraceGroup"      { return dump_bracegroup($indent, $token);      }
		case "Case"            { return dump_case($indent, $token);            }
		case "CaseItem"        { return dump_caseitem($indent, $token);        }
		case "Redirection"     { return dump_redirection($indent, $token);     }
		case "While"           { return dump_while($indent, $token);           }
		case "Until"           { return dump_until($indent, $token);           }
	}
	return "NOT-IMPLEMENTED ($type)";
}

my $p = ShellParser->new();

open(my $fh, '<', $ARGV[0]) or die $!;

my $lineno = 0;
my $result = $p->parse(sub {
	$lineno++;
	return scalar <$fh>;
});

print print_token(ShellParser::Indent->new(), $result) . "\n";
