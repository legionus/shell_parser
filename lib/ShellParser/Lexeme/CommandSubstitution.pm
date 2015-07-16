package ShellParser::Lexeme::CommandSubstitution;

use strict;
use warnings;

use base 'ShellParser::Lexeme';

sub new {
    my ($class, $tokens) = @_;
    my $self = {
        tokens => $tokens,
    };
    return bless($self, $class);
}

sub as_string {
    my ($self) = @_;
    return "\$(" . join('', map { $_->[1]->as_string() } @{$self->{tokens}}) . ")";
}

sub dequote {
    my ($self) = @_;
    return "\$(" . join('', map { $_->[1]->dequote() } @{$self->{tokens}}) . ")";
}

sub raw_string {
    my ($self) = @_;
    return "\$(" . join('', map { $_->[1]->raw_string() } @{$self->{tokens}}) . ")";
}

sub p_args {
    return "";
}

sub traverse {
    my ($self, $cb) = @_;
    foreach my $elem (@{$self->{tokens}}) {
        $cb->($elem->[1], $elem->[0]);
    }
}

1;
