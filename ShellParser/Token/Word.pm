package ShellParser::Token::Word;

sub new {
    my ($class, $value) = @_;
    return bless({
        value => $value,
    }, $class);
}

sub print {
    my ($self, $sep, $depth) = @_;
    my $v = $self->{value};
    $v =~ s/</<LESS>/g;
    $v =~ s/>/<GREATER>/g;
    $v =~ s/\\/<SLASH>/g;
    $v =~ s/\n/<NEWLINE>/g;
    print $sep x $depth . "Word($v)\n";
}

1;
