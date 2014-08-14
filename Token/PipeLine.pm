package ShellParser::Token::PipeLine;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $element) = @_;
    return bless({
        body => [$element],
    }, $class);
}

sub append {
    my ($self, $element) = @_;
    push(@{$self->{body}}, $element);
}

1;
