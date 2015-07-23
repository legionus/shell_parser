package ShellParser::Token::CommentedToken;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $token, $comments) = @_;
    return bless({
        token => $token,
        comments => $comments,
    }, $class);
}

sub traverse {
    my ($self, $cb) = @_;
    $cb->($self->{token}, "token");
    $cb->($self->{comments}, "comments");
}

1;
