package ShellParser::Token::PipeSeq;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $element) = @_;
    my $obj = {
        body => [],
    };
    append($obj, $element) if defined($element);
    return bless($obj, $class);
}

sub append {
    my ($self, $element) = @_;
    push(@{$self->{body}}, $element);
}

1;
