package ShellParser::Token::AndOrList;

use strict;
use warnings;

use base 'ShellParser::Token::List';

sub new {
    my ($class) = @_;
    return bless({
        body => [],
        sep => '',
    }, $class);
}

sub p_args {
    my ($self) = @_;
    return "sep=$self->{sep}";
}

1;
