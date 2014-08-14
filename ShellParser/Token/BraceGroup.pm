package ShellParser::Token::BraceGroup;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $body) = @_;
    return bless({
        body => $body,
    }, $class);
}

sub print {
    my ($self, $sep, $depth) = @_;
    print $sep x $depth . "BraceGroup()\n";
    $self->{body}->print($sep, $depth + 1);
}

1;
