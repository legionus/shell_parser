package ShellParser::Token::For;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $name, $words, $body) = @_;
    return bless({
        variable => $name,
        words    => $words,
        body     => $body,
    }, $class);
}

sub print {
    my $self = shift;
    $self->_p_head("variable=$self->{variable}", @_);

    my ($sep, $depth) = @_;
    if ($self->{words}) {
        foreach my $word (@{$self->{words}}) {
            $word->print($sep, $depth + 1, "word");
        }
    }
    $self->{body}->print($sep, $depth + 1, "body");
}

1;
