#!/usr/bin/env perl

use strict;
use warnings;
#use diagnostics;

use ShellParser;
use Term::ReadLine;

sub print_token {
	my ($sep, $depth, $token, $name) = @_;

	my $type = ref($token);
	$type =~ s/.*:://;

	$name //= "";
	$name = "$name: " if $name;

	print $sep x $depth . $name . $type . "(" . $token->p_args(). ")\n";
	$token->traverse(sub {
		print_token($sep, $depth + 1, @_);
	});
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
	print_token(".   ", 0, $result);
}
