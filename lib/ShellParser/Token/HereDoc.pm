package ShellParser::Token::HereDoc;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $type, $delim) = @_;
    return bless({
        type => $type,
        delimiter => $delim,
        value => "",
    }, $class);
}

sub p_args {
    my ($self) = @_;
    return "$self->{type}";
}

sub traverse {
    my ($self, $cb) = @_;
    $cb->($self->{delimiter}, "delimiter");
}

1;
