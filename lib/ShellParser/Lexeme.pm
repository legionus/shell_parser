package ShellParser::Lexeme;

use strict;
use warnings;

use overload '""' => \&as_string;

sub new {
    my ($class, $value) = @_;
    if (!defined($value)) {
        die("Assertion failed: \$lexeme->{value} is null");
    }
    return bless({ value => $value }, $class);
}

sub as_string {
    my ($self) = @_;
    return $self->{value};
}

sub raw_string {
    my ($self) = @_;
    return $self->{value};
}

1;
