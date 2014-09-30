#!/usr/bin/env perl

use strict;
use warnings;
#use diagnostics;

use ShellParser::Tokenizer;

open(F, '<', $ARGV[0]) or die $!;

my $lex = ShellParser::Tokenizer->new(sub {
	return scalar <F>;
});
while (1) {
	my ($token, $value) = $lex->_get_next_token();
	if ($token eq '' and !defined($value)) {
		last;
	}

	$value = $value->raw_string() if ref($value);
	$value =~ s/\n/\\n/g;
	print "$token, $value\n";
}

close(F);
