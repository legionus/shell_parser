package ShellParser::Token::Array;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $name, $items) = @_;
    return bless({
        non_posix => 1,
        name => $name,
        items => $items,
    }, $class);
}

sub traverse {
    my ($self, $cb) = @_;
    $cb->($self->{name}, "name");
    foreach my $elem (@{$self->{items}}) {
        $cb->($elem, "item");
    }
}

1;
