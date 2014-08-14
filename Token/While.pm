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

1;
