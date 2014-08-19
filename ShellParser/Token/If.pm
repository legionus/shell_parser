package ShellParser::Token::If;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $condition, $body) = @_;
    return bless({
        body => [
            {condition => $condition, body => $body},
        ],
    }, $class);
}

sub append {
    my ($self, $if_block) = @_;
    push @{$self->{body}}, @{$if_block->{body}};
}

sub traverse {
    my ($self, $cb) = @_;
    foreach my $elem (@{$self->{body}}) {
        if (defined($elem->{condition})) {
            $cb->($elem->{condition}, "condition");
            $cb->($elem->{body}, "then");
        } else {
            $cb->($elem->{body}, "else");
        }
    }
}

1;
