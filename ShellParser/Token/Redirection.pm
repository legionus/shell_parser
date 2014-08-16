package ShellParser::Token::Redirection;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $op, $filename) = @_;
    return bless({
        left        => undef,
        redirection => $op,
        filename    => $filename,
    }, $class);
}

sub print {
    my $self = shift;
    my $args = "$self->{redirection} $self->{filename}";
    $args = "$self->{left} $args" if defined($self->{left});
    $self->_p_head($args, @_);
}

1;
