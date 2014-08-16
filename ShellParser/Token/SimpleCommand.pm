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

sub print {
    my $self = shift;
    $self->_p_head("", @_);

    my ($sep, $depth) = @_;
    foreach my $elem (@{$self->{prefix}}) {
        $elem->print($sep, $depth + 1, "prefix");
    }
    if (defined($self->{name})) {
        $self->{name}->print($sep, $depth + 1, "name");
    }
    foreach my $elem (@{$self->{args}}) {
        $elem->print($sep, $depth + 1, "argument");
    }
}

1;
