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

sub traverse {
    my ($self, $cb) = @_;
    $cb->($self->{word}, "word");
    foreach my $elem (@{$self->{items}}) {
        $cb->($elem, "item");
    }
}

1;
