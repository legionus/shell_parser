package ShellParser::Token::Redirection;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $op, $filename) = @_;
    return bless({
        redirection => $op,
        filename    => $filename,
    }, $class);
}

sub print {
    my ($self, $sep, $depth) = @_;
    print $sep x $depth . "Redirection($self->{redirection}, $self->{filename})\n";
}

1;
