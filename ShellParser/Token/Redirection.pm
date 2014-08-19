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

sub p_args {
    my ($self) = @_;
    my $args = "$self->{redirection} $self->{filename}";
    $args = "$self->{left} $args" if defined($self->{left});
    return $args;
}

sub traverse {
    # no subitems
}

1;
