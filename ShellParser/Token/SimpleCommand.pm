package ShellParser::Token::SimpleCommand;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $prefix, $name, $args) = @_;
    return bless({
        prefix => $prefix,
        name   => $name,
        args   => $args,
    }, $class);
}

sub traverse {
    my ($self, $cb) = @_;
    foreach my $elem (@{$self->{prefix}}) {
        $cb->($elem, "prefix");
    }
    if (defined($self->{name})) {
        $cb->($self->{name}, "name");
    }
    foreach my $elem (@{$self->{args}}) {
        $cb->($elem, "argument");
    }
}

1;
