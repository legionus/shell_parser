package ShellParser::Token::CaseItem;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $left_brace, $pattern, $body, $dsemi) = @_;
    return bless({
    	pattern => $pattern,
        body => $body,
    }, $class);
}

sub traverse {
    my ($self, $cb) = @_;
    foreach my $elem (@{$self->{pattern}}) {
        $cb->($elem, "pattern");
    }
    if ($self->{body}) {
        $cb->($self->{body}, "body");
    }
}

1;
