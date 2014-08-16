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

sub print {
    my $self = shift;
    $self->_p_head("", @_);

    my ($sep, $depth) = @_;
    foreach my $elem (@{$self->{body}}) {
        if (defined($elem->{condition})) {
            $elem->{condition}->print($sep, $depth + 1, "condition");
            $elem->{body}->print($sep, $depth + 1, "then");
        } else {
            $elem->{body}->print($sep, $depth + 1, "else");
        }
    }
}

1;
