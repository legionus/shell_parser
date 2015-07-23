package ShellParser::Lexeme::Comment;

use strict;
use warnings;

use base 'ShellParser::Lexeme';

sub as_string {
    my ($self) = @_;
    return "#" . $self->SUPER::as_string();
}

sub raw_string {
    my ($self) = @_;
    return "#" . $self->SUPER::raw_string();
}

1;
