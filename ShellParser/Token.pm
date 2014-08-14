package ShellParser::Token;

sub print {
    my ($self, $sep, $depth) = @_;
    print $sep x $depth . ref($self) . " (print not implemented)\n";
}

1;
