package ShellParser::Token::For;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $name, $wordlist, $body) = @_;
    return bless({
        variable => $name,
        wordlist => $wordlist,
        body     => $body,
    }, $class);
}

sub traverse {
    my ($self, $cb) = @_;
    $cb->($self->{variable}, "variable");
    if ($self->{wordlist}) {
        $cb->($self->{wordlist}, "wordlist");
    }
    $cb->($self->{body}, "body");
}

1;
