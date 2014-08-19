package ShellParser::Token::Pipeline;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $element) = @_;
    return bless({
        body => [$element],
        banged => 0,
    }, $class);
}

sub append {
    my ($self, $element) = @_;
    push(@{$self->{body}}, $element);
}

sub p_args {
    my ($self) = @_;
    return "banged=$self->{banged}";
}

sub traverse {
    my ($self, $cb) = @_;
    foreach my $elem (@{$self->{body}}) {
        $cb->($elem);
    }
}

1;
