#!/usr/bin/env perl

use strict;
use warnings;
#use diagnostics;

use Switch;

use ShellParser;
use Term::ReadLine;

my $sep = "\t";
my $depth = 0;

sub dump_lexeme {
	my ($token) = @_;
	return $token->as_string();
}

sub dump_list {
	my ($token) = @_;
	my $childs = [ map { print_token($_) } @{$token->{body}} ];
	return join("\n", @{$childs});
}

sub dump_andorlist {
	my ($token) = @_;
	my $childs = [ print_token($token->{first}) ];

	foreach my $elem (@{$token->{rest}}) {
		push(@{$childs}, $elem->[0] // "");
		push(@{$childs}, print_token($elem->[1]));
	}
	return join(" ", @{$childs}) . ($token->{sep} || "");
}

sub dump_pipeline {
	my ($token) = @_;
	my $s = ($token->{banged} ? "! " : "");
	my $childs = [ map { print_token($_) } @{$token->{body}} ];
	$s .= join(" | ", @{$childs});
	return $s;
}

sub dump_simplecommand {
	my ($token) = @_;
	my $prefix = [ map { print_token($_) } @{$token->{prefix}} ];
	my $args   = [ map { print_token($_) } @{$token->{args}}   ];

	my @cmd;
	push(@cmd, join(" ", @{$prefix}))       if @{$prefix};
	push(@cmd, print_token($token->{name})) if $token->{name};
	push(@cmd, join(" ", @{$args}))         if @{$args};

	return join(" ", @cmd);
}

sub dump_compoundcommand {
	my ($token) = @_;
	my $childs = [ print_token($token->{body}) ];
	return join(" ", @{$childs});
}

sub dump_if {
	my ($token) = @_;
	my $childs = [];
	foreach my $body (@{$token->{body}}) {
		if ($body->{condition}) {
			my $kw = !@{$childs} ? "if" : "elif";
			push(@{$childs}, "$kw " . print_token($body->{condition}) . " then");
			push(@{$childs}, print_token($body->{body}));
		}
		else {
			push(@{$childs}, "else");
			push(@{$childs}, print_token($body->{body}));
		}
	}
	push(@{$childs}, "fi");
	return join("\n", @{$childs});
}

sub print_token {
	my ($token, $name) = @_;

	my $type = ref($token);
	$type =~ s/.*:://;

	$name //= "";
	$name = "$name: " if $name;

	#print $name . $type . "(" . $token->p_args(). ")\n";

	switch ($type) {
		case /^(Lexeme|Word|QString|QQString|LineConcat)$/ { return dump_lexeme($token); }
		case "List"            { return dump_list($token);            }
		case "AndOrList"       { return dump_andorlist($token);       }
		case "Pipeline"        { return dump_pipeline($token);        }
		case "SimpleCommand"   { return dump_simplecommand($token);   }
		case "CompoundCommand" { return dump_compoundcommand($token); }
		case "If"              { return dump_if($token);              }
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
	print print_token($result);
	print "\n";
}
