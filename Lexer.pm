package Lexer;

my @reserved_words = qw(if then else elif fi done do case esac while until for in);

sub new {
    my ($class, $reader) = @_;
    my $self = {
        state => {},
        reader => $reader,
        prev_token => '',
        inject => undef,
    };
    return bless($self, $class);
}

sub _get_next_token {
    my ($self) = @_;

    if (!defined($self->{current_line})) {
        $self->{current_line} = $self->{reader}->('new');
    }
    if (!defined($self->{current_line})) {
        return ('', undef);
    }

    my $prev_token = $self->{prev_token};
    $self->{prev_token} = '';

    my $inject = $self->{inject};
    $self->{inject} = undef;
    if ($inject) {
        return @$inject;
    }

    my $target = \$self->{current_line};
    TOKEN: {
        return ('NEWLINE', '') if $$target =~ /\G \n     /gcx;
        return ('NEWLINE', $1) if $$target =~ /\G (\#.*) /gcx;
        redo                   if $$target =~ /\G \s+    /gcx;

        return ('AND_IF',    $1) if $$target =~ /\G (&&)   /gcxi;
        return ('OR_IF',     $1) if $$target =~ /\G (\|\|) /gcxi;
        return ('DSEMI',     $1) if $$target =~ /\G (;;)   /gcxi;
        return ('DLESS',     $1) if $$target =~ /\G (<<)   /gcxi;
        return ('DGREAT',    $1) if $$target =~ /\G (>>)   /gcxi;
        return ('LESSAND',   $1) if $$target =~ /\G (<&)   /gcxi;
        return ('GREATAND',  $1) if $$target =~ /\G (>&)   /gcxi;
        return ('LESSGREAT', $1) if $$target =~ /\G (<>)   /gcxi;
        return ('DLESSDASH', $1) if $$target =~ /\G (<<-)  /gcxi;
        return ('CLOBBER',   $1) if $$target =~ /\G (>\|)  /gcxi;
        return ('CLOBBER',   $1) if $$target =~ /\G (>\|)  /gcxi;

        if ($$target =~ /\G (for) /gcx) {
            $self->{prev_token} = 'For';
            return ('For', $1);
        }
        foreach my $w (@reserved_words) {
            if ($$target =~ /\G (\Q$w\E) /gcx) {
                return (uc(substr($w, 0, 1)) . substr($w, 1), $1);
            }
        }

        if ($$target =~ /\G ([A-Za-z0-9\$\"'=]+) /gcx) {
            my $word = $1;
            if ($prev_token eq 'For') {
                return ('NAME', $word);
            }
            if ($$target =~ /\G \ * (\() /gcx) {
                $self->{inject} = ['(', $1];
                return ('NAME', $word);
            }
            return ('WORD', $word);
            return ('UNKNOWN_WORD', $word);
        }

        return ($1, $1)       if $$target =~ /\G ([()|;&]) /gcx;
        return ('Lbrace', $1) if $$target =~ /\G ({)       /gcx;
        return ('Rbrace', $1) if $$target =~ /\G (})       /gcx;
        return ('Bang', $1)   if $$target =~ /\G (!)       /gcx;

        return ('UNKNOWN', $1) if $$target =~ /\G (.) /gcx;

        $self->{current_line} = undef;
        return $self->_get_next_token();
    }
}

1;
