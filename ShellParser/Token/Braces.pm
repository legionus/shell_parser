package ShellParser::Token::Braces;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $body) = @_;
    return bless({
        body => $body,
    }, $class);
}

1;
