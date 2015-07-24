#!/usr/bin/env perl

use strict;
use warnings;
#use diagnostics;

use ShellParser::Tokenizer;

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

open(F, '<', $ARGV[0]) or die $!;

my $lex = ShellParser::Tokenizer->new(sub {
	return scalar <F>;
});
while (1) {
	my ($token, $value) = $lex->_get_next_token();
	if ($token eq '' and !defined($value)) {
		last;
	}

	if (ref($value)) {
		print_token(".   ", 0, $value, $token);
	} else {
		$value =~ s/\n/\\n/g;
		print "$token: String[$value]\n";
	}
}

close(F);
