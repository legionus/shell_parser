package ShellParser::Token::List;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class) = @_;
    return bless({
        body => [],
    }, $class);
}

sub append {
    my ($self, $element) = @_;
    push(@{$self->{body}}, $element);
    return $self;
}

sub prepend {
    my ($self, $element) = @_;
    unshift(@{$self->{body}}, $element);
    return $self;
}

sub traverse {
    my ($self, $cb) = @_;
    foreach my $elem (@{$self->{body}}) {
        $cb->($elem);
    }
}

1;
