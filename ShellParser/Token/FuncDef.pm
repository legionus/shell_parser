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

sub p_args {
    my ($self) = @_;
    return "name=$self->{name}";
}

sub traverse {
    my ($self, $cb) = @_;
    $cb->($self->{body}, "body");
    if ($self->{redirect}) {
        foreach my $redirect (@{$self->{redirect}}) {
            $cb->($redirect, "redirect");
        }
    }
}

1;
