#!/usr/bin/env perl

use strict;
use warnings;
#use diagnostics;

use Switch;

use ShellParser;
use Term::ReadLine;

my $sep = "\t";
my $depth = 0;
my $in_condition = 0;

sub dump_lexeme {
	my ($sep, $depth, $token) = @_;
	return $token->as_string();
}

sub dump_list {
	my ($sep, $depth, $token) = @_;
	my $delim = "\n";

	if ($in_condition) {
		$delim = " ";
		$sep = "";
		$depth = 0;
	}

	my $childs = [ map { print_token($sep, $depth, $_) } @{$token->{body}} ];
	return join($delim, @{$childs});
}

sub dump_andorlist {
	my ($sep, $depth, $token) = @_;
	my $delim = "\n";

	if ($in_condition) {
		$delim = " ";
		$sep = "";
		$depth = 0;
	}

	my $childs = [ ($sep x $depth) . print_token($sep, $depth, $token->{first}) ];

	foreach my $elem (@{$token->{rest}}) {
		$childs->[-1] .= " " . ($elem->[0] // "");
		push(@{$childs},  ($sep x ($depth+1)) . print_token($sep, $depth, $elem->[1]));
	}

	if ($in_condition && !$token->{sep}) {
		$token->{sep} = ";";
	}

	return join($delim, @{$childs}) . ($token->{sep} || "");
}

sub dump_pipeline {
	my ($sep, $depth, $token) = @_;

	my $pipe_sep   = $sep;
	my $pipe_depth = $depth;

	my $childs = [];
	foreach my $a (@{$token->{body}}) {
		my $tailing_space = ((@{$token->{body}} - @{$childs}) == 1 ? "" : " ");

		push(@$childs, print_token($pipe_sep, $pipe_depth, $a) . $tailing_space);

		$pipe_sep   = "";
		$pipe_depth = 1;
	}

	my $s = ($token->{banged} ? "! " : "");
	$s .= join("|", @{$childs});
	return $s;
}

sub dump_redirection {
	my ($sep, $depth, $token) = @_;
	return ($token->{left} // "") .
		$token->{redirection} .
		print_token($sep, 0, $token->{filename});
}

sub dump_simplecommand {
	my ($sep, $depth, $token) = @_;

	my $prefix = [ map { print_token($sep, $depth, $_) } @{$token->{prefix}} ];
	my $args   = [ map { print_token($sep, $depth, $_) } @{$token->{args}}   ];

	my @cmd;
	push(@cmd, join(" ", @{$prefix}))                     if @{$prefix};
	push(@cmd, print_token($sep, $depth, $token->{name})) if $token->{name};
	push(@cmd, join(" ", @{$args}))                       if @{$args};

	my $s = join(" ", @cmd);
	return $s;
}

sub dump_compoundcommand {
	my ($sep, $depth, $token) = @_;
	my $childs = [ print_token($sep, $depth, $token->{body}) ];
	return join(" ", @{$childs});
}

sub dump_if {
	my ($sep, $depth, $token) = @_;
	my $childs = [];
	foreach my $body (@{$token->{body}}) {
		if ($body->{condition}) {
			$in_condition = 1;

			my $condition = [];
			push(@{$condition}, (!@{$childs} ? "if" : ($sep x $depth) . "elif"));
			push(@{$condition}, print_token($sep, 0, $body->{condition}));
			push(@{$condition}, "then");

			$in_condition = 0;

			push(@{$childs}, join(" ", @{$condition}));
			push(@{$childs}, print_token($sep, $depth+1, $body->{body}));
		}
		else {
			push(@{$childs}, ($sep x $depth) . "else");
			push(@{$childs}, print_token($sep, $depth+1, $body->{body}));
		}
	}
	push(@{$childs}, ($sep x $depth) . "fi");
	return join("\n", @{$childs});
}

sub dump_for {
	my ($sep, $depth, $token) = @_;
	my $childs = [];

	push(@{$childs}, "for");
	push(@{$childs}, print_token($sep, 0, $token->{variable}));

	my $words = [ map { print_token($sep, 0, $_) } @{$token->{words}} ];
	if (@{$words}) {
		push(@{$childs}, "in");
		push(@{$childs}, join(" ", @{$words}) . ";");
	}

	push(@{$childs}, print_token($sep, $depth, $token->{body}));
	return join(" ", @{$childs});
}

sub dump_while {
	my ($sep, $depth, $token) = @_;
	my $childs = [];

	$in_condition = 1;
	push(@{$childs}, "while " . print_token($sep, 0, $token->{condition}));
	$in_condition = 0;

	push(@{$childs}, print_token($sep, $depth, $token->{body}));
	return join("\n", @{$childs});
}

sub dump_until {
	my ($sep, $depth, $token) = @_;
	my $childs = [];

	$in_condition = 1;
	push(@{$childs}, "until " . print_token($sep, 0, $token->{condition}));
	$in_condition = 0;

	push(@{$childs}, print_token($sep, $depth, $token->{body}));
	return join("\n", @{$childs});
}

sub dump_dogroup {
	my ($sep, $depth, $token) = @_;
	my $childs = [];
	push(@{$childs}, "do");
	push(@{$childs}, print_token($sep, $depth+1, $token->{body}));
	push(@{$childs}, ($sep x $depth) . "done");
	return join("\n", @{$childs});
}

sub dump_case {
	my ($sep, $depth, $token) = @_;
	my $childs = [];

	push(@{$childs}, "case " . print_token($sep, 0, $token->{word}) . " in");
	foreach my $item (@{$token->{items}}) {
		push(@{$childs}, print_token($sep, $depth+1, $item));
	}
	push(@{$childs}, ($sep x $depth) . "esac");

	return join("\n", @{$childs});
}

sub dump_caseitem {
	my ($sep, $depth, $token) = @_;
	my $childs   = [];
	my $patterns = [];

	foreach my $pattern (@{$token->{pattern}}) {
		push(@{$patterns}, "|")
			if @{$patterns};
		push(@{$patterns}, print_token($sep, 0, $pattern));
	}

	push(@{$childs}, ($sep x $depth) . "(" .  join("", @{$patterns}) . ")");
	push(@{$childs}, print_token($sep, $depth+1, $token->{body}));
	push(@{$childs}, ($sep x ($depth+1)) . ";;");

	return join("\n", @{$childs});
}

sub dump_bracegroup {
	my ($sep, $depth, $token) = @_;
	my $childs = [];
	push(@{$childs}, "{");
	push(@{$childs}, print_token($sep, $depth+2, $token->{body}));
	push(@{$childs}, ($sep x ($depth+1)) . "}");
	return join("\n", @{$childs});
}

sub dump_funcdef {
	my ($sep, $depth, $token) = @_;
	my $childs = [];
	push(@{$childs}, print_token($sep, 0, $token->{name}) . '()');
	push(@{$childs}, print_token($sep, $depth, $token->{body}));
	return join("\n", @{$childs});
}


sub print_token {
	my ($sep, $depth, $token) = @_;

	my $type = ref($token);
	$type =~ s/.*:://;

	switch ($type) {
		case /^(Lexeme|Word|QString|QQString|LineConcat)$/ {
		                         return dump_lexeme($sep, $depth, $token);          }
		case "List"            { return dump_list($sep, $depth, $token);            }
		case "AndOrList"       { return dump_andorlist($sep, $depth, $token);       }
		case "Pipeline"        { return dump_pipeline($sep, $depth, $token);        }
		case "SimpleCommand"   { return dump_simplecommand($sep, $depth, $token);   }
		case "CompoundCommand" { return dump_compoundcommand($sep, $depth, $token); }
		case "If"              { return dump_if($sep, $depth, $token);              }
		case "For"             { return dump_for($sep, $depth, $token);             }
		case "DoGroup"         { return dump_dogroup($sep, $depth, $token);         }
		case "FuncDef"         { return dump_funcdef($sep, $depth, $token);         }
		case "BraceGroup"      { return dump_bracegroup($sep, $depth, $token);      }
		case "Case"            { return dump_case($sep, $depth, $token);            }
		case "CaseItem"        { return dump_caseitem($sep, $depth, $token);        }
		case "Redirection"     { return dump_redirection($sep, $depth, $token);     }
		case "While"           { return dump_while($sep, $depth, $token);           }
		case "Until"           { return dump_until($sep, $depth, $token);           }
	}
	return "NOT-IMPLEMENTED";
}

my $lineno = 0;
my $reader;
if ($ARGV[0]) {
    open(my $fh, '<', $ARGV[0]) or die $!;
    $reader = sub {
        $lineno++;
        return scalar <$fh>;
    };
} else {
    my $term = Term::ReadLine->new('Shell');
    my $OUT = $term->OUT || \*STDOUT;
    $term->ornaments(0);
    $reader = sub {
        my ($xxx, $type) = @_;
        $type //= "";
        $lineno++;
        my $line = $term->readline("$type >>> ");
        $line .= "\n" if $line;
        return $line;
    }
}

my $p = ShellParser->new();
my $result = $p->parse($reader);
# FIXME close($fh);

if (!$result) {
    my $err = $p->error;

    my $line = ($err->{line} // "(EOF)");
    chomp($line);
    $line =~ s/\t/ /;

    my $lineno_prefix = "$lineno: ";
    print $lineno_prefix . $line . "\n";
    print "-" x (length($lineno_prefix) + ($err->{position} // 1) - 1) . "^\n";
    print $err->{message} . "\n";
    exit(1);
} else {
	print print_token($sep, $depth, $result);
	print "\n";
}
