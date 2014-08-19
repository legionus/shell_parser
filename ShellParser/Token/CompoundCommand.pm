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

sub traverse {
    my ($self, $cb) = @_;
    $cb->($self->{body}, "body");
    foreach my $elem (@{$self->{redirect}}) {
        $cb->($elem, "redirect");
    }
}

1;
