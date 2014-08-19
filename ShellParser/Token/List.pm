package ShellParser::Token::List;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $body) = @_;
    return bless({
        body => [$body],
    }, $class);
}

sub append {
    my ($self, $element) = @_;
    push(@{$self->{body}}, $element);
}

sub traverse {
    my ($self, $cb) = @_;
    foreach my $elem (@{$self->{body}}) {
        $cb->($elem);
    }
}

1;
