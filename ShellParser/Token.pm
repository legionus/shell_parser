package ShellParser::Token;

sub _p_head {
    my ($self, $args, $sep, $depth, $parent_role) = @_;

    if (!$parent_role) {
        $parent_role = "";
    } else {
        $parent_role .= ": ";
    }

    my $name = ref($self);
    $name =~ s/.*:://;

    $self->_p($parent_role . $name . "(" . $args. ")", $sep, $depth);
}

sub _p {
    my ($self, $msg, $sep, $depth) = @_;
    print $sep x $depth . $msg . "\n";
}

sub print {
    my $self = shift;
    $self->_p_head("print not implemented", @_);
}

1;
