package ShellParser::Token::CompoundCommand;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $body, $redirect) = @_;
    return bless({
        body     => $body,
        redirect => $redirect,
    }, $class);
}

sub print {
    my $self = shift;
    $self->_p_head("", @_);

    my ($sep, $depth) = @_;
    $self->{body}->print($sep, $depth + 1, "body");
    foreach my $elem (@{$self->{redirect}}) {
        $elem->print($sep, $depth + 1, "redirect");
    }
}

1;
