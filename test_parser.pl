#!/usr/bin/env perl

use strict;
use warnings;
#use diagnostics;

use ShellParser;

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

open(my $fh, '<', $ARGV[0]) or die $!;
my $p = ShellParser->new();
my $result = $p->parse($fh);
close($fh);

if (!$result) {
    my $err = $p->error;

    my $line = ($err->{line} // "(EOF)");
    chomp($line);
    $line =~ s/\t/ /;

    my $lineno_prefix = "$err->{lineno}: ";
    print $lineno_prefix . $line . "\n";
    print "-" x (length($lineno_prefix) + ($err->{position} // 1) - 1) . "^\n";
    print $err->{message} . "\n";
    exit(1);
} else {
	print_token(".   ", 0, $result);
}
