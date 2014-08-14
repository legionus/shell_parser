package ShellParser::Token::Command;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $name, $args, $prefix) = @_;
    return bless({
        name   => $name,
        args   => $args,
        prefix => $prefix,
    }, $class);
}

1;
