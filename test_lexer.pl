#!/usr/bin/env perl

use strict;
use warnings;
#use diagnostics;

use Lexer;

use constant NEWLINE => "<NEWLINE>";
use constant TAB => "<TAB>";


my $orig_string = "";
my $indicators = "";
my $ind = "?";

sub concat {
    my ($part) = @_;

    if ($part) {
        $part =~ s/\t/<TAB>/g;
        $orig_string .= $part;
        $indicators .= $ind . ("-" x (length($part) - 1));
        $ind = "-";
    }
}

sub flush {
    if ($orig_string) {
        print $orig_string . "\n";
        print $indicators . "\n";
    }

    $orig_string = "";
    $indicators = "";
}


if ($ARGV[0]) {
    open(F, '<', $ARGV[0]) or die $!;
}else {
    *F = *STDIN;
}

my $lex = Lexer->new(sub {
	return scalar <F>;
});

while (1) {
	my $lexem = $lex->get_next_lexem();
    last if !defined($lexem);

    my ($first_part, @parts) = split(/\n/, $lexem, -1);
    $ind = "^";
    concat($first_part);
    foreach my $part (@parts) {
        concat(NEWLINE);
        flush();
        concat($part);
    }
}
flush();

close(F);
