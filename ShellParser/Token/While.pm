package ShellParser::Token::While;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $condition, $body) = @_;
    return bless({
        condition => $condition,
        body      => $body,
    }, $class);
}

sub print {
    my $self = shift;
    $self->_p_head("", @_);

    my ($sep, $depth) = @_;
    $self->{condition}->print($sep, $depth + 1, "condition");
    $self->{body}->print($sep, $depth + 1, "body");
}

1;
