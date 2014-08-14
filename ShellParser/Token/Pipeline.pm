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

sub print {
    my ($self, $sep, $depth) = @_;
    print $sep x $depth . "Pipeline(banged=$self->{banged})\n";
    foreach my $elem (@{$self->{body}}) {
        $elem->print($sep, $depth + 1);
    }
}

1;
