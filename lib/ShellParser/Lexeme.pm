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

sub p_args {
    my ($self) = @_;
    my $v = $self->{value};

    $v =~ s/</<LESS/g;
    $v =~ s/>/<GREATER>/g;
    $v =~ s/<LESS/<LESS>/g;

    $v =~ s/\(/<OPEN>/g;
    $v =~ s/\)/<CLOSE>/g;
    $v =~ s/\\/<SLASH>/g;
    $v =~ s/\t/<TAB>/g;
    $v =~ s/\n/<NEWLINE>/g;
    return $v;
}

sub traverse {
}

1;
