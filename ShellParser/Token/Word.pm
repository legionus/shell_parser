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

sub p_args {
    my ($self) = @_;
    my $v = $self->{value};
    $v =~ s/</<LESS>/g;
    $v =~ s/>/<GREATER>/g;
    $v =~ s/\\/<SLASH>/g;
    $v =~ s/\n/<NEWLINE>/g;
    return $v;
}

sub traverse {
    # no subitems
}

1;
