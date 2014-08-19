package ShellParser::Token::Until;

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

sub traverse {
    my ($self, $cb) = @_;
    $cb->($self->{condition}, "condition");
    $cb->($self->{body}, "body");
}

1;
