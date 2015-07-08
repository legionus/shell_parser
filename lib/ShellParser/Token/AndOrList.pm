package ShellParser::Token::AndOrList;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $first) = @_;
    return bless({
        first => $first,
        rest => [],
        sep => undef,
    }, $class);
}

sub append {
    my ($self, $op, $element) = @_;
    push(@{$self->{rest}}, [$op, $element]);
}

sub p_args {
    my ($self) = @_;
    my $sep = $self->{sep};
    $sep = "" if $sep eq "\n";
    return "sep=$sep";
}

sub traverse {
    my ($self, $cb) = @_;
    $cb->($self->{first}, "first");
    foreach my $elem (@{$self->{rest}}) {
        $cb->($elem->[1], "rest[$elem->[0]]");
    }
}

1;
