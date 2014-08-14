package ShellParser::Token::FuncDef;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $name, $body) = @_;
    return bless({
        name => $name,
        body => $body,
    }, $class);
}

1;
