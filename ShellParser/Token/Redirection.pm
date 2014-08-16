package ShellParser::Token::Redirection;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $op, $filename) = @_;
    return bless({
        redirection => $op,
        filename    => $filename,
    }, $class);
}

sub print {
    my $self = shift;
    $self->_p_head("$self->{redirection} $self->{filename}", @_);
}

1;
