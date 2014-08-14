package ShellParser::Token::AndOrList;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $first) = @_;
    return bless({
        first => $first,
        rest => [],
        sep => undef,
    }, $class);
}

sub append {
    my ($self, $op, $element) = @_;
    push(@{$self->{rest}}, [$op, $element]);
}

sub print {
    my ($self, $sep, $depth) = @_;
    print $sep x $depth . "AndOrList(restlen=" . scalar(@{$self->{rest}}) . " sep=$self->{sep})\n";
    if (!@{$self->{rest}}) {
        $self->{first}->print($sep, $depth + 1);
    } else {
        print $sep x $depth . $sep . "AndOrList::first()\n";
        $self->{first}->print($sep, $depth + 2);
        foreach my $elem (@{$self->{rest}}) {
            print $sep x $depth . $sep . "AndOrList::rest(op=" . $elem->[0] . ")\n";
            $elem->[1]->print($sep, $depth + 2);
        }
    }
}

1;
