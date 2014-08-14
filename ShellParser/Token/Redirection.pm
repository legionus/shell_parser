package ShellParser::Token::Redirection;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $op, $filename) = @_;
    return bless({
        redirection => $op,
        filename    => $filename,
    }, $class);
}

1;
