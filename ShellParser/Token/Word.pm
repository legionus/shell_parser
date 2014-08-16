package ShellParser::Token::Word;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $value) = @_;
    return bless({
        value => $value,
    }, $class);
}

sub print {
    my $self = shift;
    my $v = $self->{value};
    $v =~ s/</<LESS>/g;
    $v =~ s/>/<GREATER>/g;
    $v =~ s/\\/<SLASH>/g;
    $v =~ s/\n/<NEWLINE>/g;
    $self->_p_head($v, @_);
}

1;
