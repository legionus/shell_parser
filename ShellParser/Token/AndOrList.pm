package ShellParser::Token::AndOrList;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $first) = @_;
    return bless({
		first => $first,
        rest => [],
        sep => 'BUG!',
    }, $class);
}

sub append {
    my ($self, $op, $element) = @_;
    push(@{$self->{rest}}, [$op, $element]);
}

1;
