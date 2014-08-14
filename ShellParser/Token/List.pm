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

sub print {
    my ($self, $sep, $depth) = @_;
    print $sep x $depth . "List()\n";
    foreach my $elem (@{$self->{body}}) {
        $elem->print($sep, $depth + 1);
    }
}

1;
