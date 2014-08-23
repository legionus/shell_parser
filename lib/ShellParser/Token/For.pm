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

sub traverse {
    my ($self, $cb) = @_;
    $cb->($self->{variable}, "variable");
    if ($self->{words}) {
        foreach my $word (@{$self->{words}}) {
            $cb->($word, "word");
        }
    }
    $cb->($self->{body}, "body");
}

1;
