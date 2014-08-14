#!/usr/bin/env perl

use strict;
use warnings;
#use diagnostics;

use Data::Dumper;
use ShellParser;

open(my $fh, '<', $ARGV[0]) or die $!;
my $p = ShellParser->new();
my $result = $p->parse($fh);
if (!$result) {
    print $p->error;
} else {
    $result->print("  ", 0);
}
close($fh);
