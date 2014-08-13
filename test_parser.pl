#!/usr/bin/env perl

use strict;
use warnings;
#use diagnostics;

use Data::Dumper;
use ShellParser;

open(my $fh, '<', 't/data/op_0001.sh') or die $!;
my $p = ShellParser->new();
my $result = $p->parse($fh);
if (!$result) {
    print $p->error;
} else {
    print Dumper($result);
}
close($fh);
