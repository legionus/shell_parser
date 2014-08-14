package ShellParser::Token::Bang;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $body) = @_;
    return bless({
        name => '!',
        body => $body,
    }, $class);
}

1;
