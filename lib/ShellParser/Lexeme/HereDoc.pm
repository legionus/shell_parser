package ShellParser::Lexeme::HereDoc;

use strict;
use warnings;

use base 'ShellParser::Lexeme';

sub new {
    my ($class, $type, $here_end) = @_;
    return bless({
        type => $type,
        here_end => $here_end,
        value => "",
    }, $class);
}

sub as_string {
    my ($self) = @_;
    return $self->{type} . $self->{here_end}->as_string();
}

sub dequote {
    my ($self) = @_;
    return $self->{type} . $self->{here_end}->dequote();
}

sub raw_string {
    my ($self) = @_;
    return $self->{type} . $self->{here_end}->raw_string();
}

sub p_args {
    my ($self) = @_;
    return "$self->{type}";
}

sub traverse {
    my ($self, $cb) = @_;
    $cb->($self->{here_end}, "delimiter");
}

1;
