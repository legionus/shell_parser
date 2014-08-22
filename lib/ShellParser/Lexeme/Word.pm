package ShellParser::Lexeme::Word;

use strict;
use warnings;

use base 'ShellParser::Lexeme';

sub new {
    my ($class, $value_parts) = @_;
    my $self = {
        value => $value_parts,
    };
    return bless($self, $class);
}

sub as_string {
    my ($self) = @_;
    return join('', map { $_->as_string() } @{$self->{value}});
}

sub raw_string {
    my ($self) = @_;
    return join('', map { $_->raw_string() } @{$self->{value}});
}

1;
