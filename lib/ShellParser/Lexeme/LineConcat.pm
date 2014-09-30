package ShellParser::Lexeme::LineConcat;

use strict;
use warnings;

use base 'ShellParser::Lexeme';

sub new {
    my ($class) = @_;
    return bless({}, $class);
}

sub as_string {
    return "";
}

sub raw_string {
    return "\\\n";
}

sub p_args {
    return "";
}

1;
