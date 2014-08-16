package ShellParser::Token::Case;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $word, $items) = @_;
    return bless({
        word => $word,
        items => $items,
    }, $class);
}

sub print {
    my $self = shift;
    $self->_p_head("", @_);

    my ($sep, $depth) = @_;
    $self->{word}->print($sep, $depth + 1, "word");
    foreach my $elem (@{$self->{items}}) {
        $elem->print($sep, $depth + 1, "item");
    }
}

1;
