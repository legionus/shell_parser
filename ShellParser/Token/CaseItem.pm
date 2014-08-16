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

sub print {
    my $self = shift;
    $self->_p_head("", @_);

    my ($sep, $depth) = @_;
    foreach my $elem (@{$self->{pattern}}) {
	    $elem->print($sep, $depth + 1, "pattern");
    }
    if ($self->{body}) {
	    $self->{body}->print($sep, $depth + 1, "body");
    }
}

1;
