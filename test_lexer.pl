#!/usr/bin/env perl

use strict;
use warnings;
#use diagnostics;

use Lexer;

open(F, '<', 't/data/op_0001.sh') or die $!;

my $lex = Lexer->new(sub {
	return scalar <F>;
});
while (1) {
	my ($token, $value) = $lex->_get_next_token();
	if ($token eq '' and !defined($value)) {
		last;
	}

	print "$token, $value\n";
}

close(F);
