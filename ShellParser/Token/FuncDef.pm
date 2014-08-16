package ShellParser::Token::FuncDef;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $name, $body, $redirect) = @_;
    return bless({
        name     => $name,
        body     => $body,
        redirect => $redirect,
    }, $class);
}

sub print {
    my $self = shift;
    $self->_p_head("name=$self->{name}", @_);

    my ($sep, $depth) = @_;
    $self->{body}->print($sep, $depth + 1, "body");
    if ($self->{redirect}) {
        foreach my $redirect (@{$self->{redirect}}) {
            $redirect->print($sep, $depth + 1, "redirect");
        }
    }
}

1;
