package ShellParser::Token::DoGroup;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $body) = @_;
    return bless({
        body => $body,
    }, $class);
}

sub traverse {
    my ($self, $cb) = @_;
    $cb->($self->{body});
}

1;
