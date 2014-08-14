package ShellParser::Token::List;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $body, $separator) = @_;
    return bless({
        separator => $separator,
        body      => $body,
    }, $class);
}

1;
