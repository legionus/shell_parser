package ShellParser::Token::Case;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $word) = @_;
    return bless({
        word => $word,
    }, $class);
}

1;
