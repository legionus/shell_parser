package ShellParser::Token::FuncDef;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $name, $body, $redirect) = @_;
    return bless({
        name     => $name,
        body     => $body,
        redirect => $redirect,
    }, $class);
}

1;
