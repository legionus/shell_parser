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
    my ($self, $sep, $depth) = @_;
    print $sep x $depth . "For(variable=$self->{variable})\n";
    if ($self->{words}) {
        print $sep x $depth . $sep . "For::words()\n";
        foreach my $word (@{$self->{words}}) {
            $word->print($sep, $depth + 2);
        }
    }
    print $sep x $depth . $sep . "For::body()\n";
    $self->{body}->print($sep, $depth + 2);
}

1;
