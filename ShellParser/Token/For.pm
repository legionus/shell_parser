package ShellParser::Token::For;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $name, $words, $body) = @_;
    return bless({
        variable => $name,
        words    => $words,
        body     => $body,
    }, $class);
}

1;
