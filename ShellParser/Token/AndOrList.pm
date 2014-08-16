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
    my $self = shift;
    $self->_p_head("sep=$self->{sep}", @_);

    my ($sep, $depth) = @_;
    $self->{first}->print($sep, $depth + 1, "first");
    foreach my $elem (@{$self->{rest}}) {
        $elem->[1]->print($sep, $depth + 1, "rest[$elem->[0]]");
    }
}

1;
