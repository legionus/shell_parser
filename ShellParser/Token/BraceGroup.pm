package ShellParser::Token::BraceGroup;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $body) = @_;
    return bless({
        body => $body,
    }, $class);
}

sub print {
    my $self = shift;
    $self->_p_head("", @_);

    my ($sep, $depth) = @_;
    $self->{body}->print($sep, $depth + 1);
}

1;
