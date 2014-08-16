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
    my ($self, $sep, $depth) = @_;
    print $sep x $depth . "If()\n";
    foreach my $elem (@{$self->{body}}) {
        if (defined($elem->{condition})) {
            print $sep x $depth . $sep . "If::condition()\n";
            $elem->{condition}->print($sep, $depth + 2);
        } else {
            print $sep x $depth . $sep . "If::else()\n";
        }
        print $sep x $depth . $sep . "If::then()\n";
        $elem->{body}->print($sep, $depth + 2);
    }
}

1;
