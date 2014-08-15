package Lexer;

use strict;
use warnings;

my @reserved_words = qw(
    while
    until
    then
    in
    if
    for
    fi
    esac
    else
    elif
    done
    do
    case
);

my %operators = (
    '&&'  => 'AND_IF',
    '||'  => 'OR_IF',
    ';;'  => 'DSEMI',
    '<<'  => 'DLESS',
    '>>'  => 'DGREAT',
    '<&'  => 'LESSAND',
    '>&'  => 'GREATAND',
    '<>'  => 'LESSGREAT',
    '<<-' => 'DLESSDASH',
    '>|'  => 'CLOBBER',
);

sub new {
    my ($class, $reader) = @_;
    my $self = {
        state => {},
        reader => $reader,
        for_state => 0,
        case_state => 0,
        downgrade_assignment_word => 0,
    };
    return bless($self, $class);
}

sub _get_rest_q_string {
    my ($self) = @_;
    my $target = \$self->{current_line};

    my $value = "";

    $$target =~ /\G ([^']*'|.*) /gcx;
    $value = $1;
    if ($value !~ /'$/) {
        $self->{current_line} = $self->{reader}->('token', "'");
        die "Unexpected end of input" if !defined($self->{current_line});
        $value .= "\n" . $self->_get_rest_q_string();
    }

    return $value;
}

sub _get_rest_qq_string {
    my ($self) = @_;
    my $target = \$self->{current_line};

    my $value = "";

    while ($$target =~ /\G (.) /gcx) {
        my $c = $1;
        $value .= $c;
        if ($c eq '\\') {
            if ($$target =~ /\G (.) /gcx) {
                $value .= $1;
            } else {
                $value .= "\n";
                $self->{current_line} = $self->{reader}->('token', '"');
                die "Unexpected end of input" if !defined($self->{current_line});
                $target = \$self->{current_line};
            }
        } elsif ($c eq '"') {
            return $value;
        } elsif ($c eq '$') {
            if ($$target =~ /\G (\(\() /gcx) {
                $value .= $1 . $self->_get_rest_dbb_string();
            }
        }
    }

    $self->{current_line} = $self->{reader}->('token', '"');
    die "Unexpected end of input" if !defined($self->{current_line});
    $value .= "\n" . $self->_get_rest_qq_string();
    return $value;
}

sub _get_rest_qx_string {
    my ($self) = @_;
    my $target = \$self->{current_line};

    my $value = "";

    $$target =~ /\G ([^`]*`|.*) /gcx;
    $value = $1;
    if ($value !~ /`$/) {
        # FIXME: handle \", etc.
        $self->{current_line} = $self->{reader}->('token', '`');
        die "Unexpected end of input" if !defined($self->{current_line});
        $value .= "\n" . $self->_get_rest_qq_string();
    }

    return $value;
}

sub _get_rest_dbb_string
{
    my ($self) = @_;
    my $target = \$self->{current_line};

    my $value = "";

    $$target =~ /\G (.*?\)\)|.*) /gcx;
    $value = $1;
    if ($value !~ /\)\)$/) {
        # FIXME
        $self->{current_line} = $self->{reader}->('token', '"');
        die "Unexpected end of input" if !defined($self->{current_line});
        $value .= "\n" . $self->_get_rest_dbb_string();
    }

    return $value;
}

sub _get_rest_db_string
{
    my ($self) = @_;
    my $target = \$self->{current_line};

    my $value = "";

    while ($$target =~ /\G (.) /gcx) {
        my $c = $1;
        $value .= $c;
        if ($c != /[^\s<>()|;&]/) {
            my $word = $self->_get_word();
            next if !defined($word);
            $value .= $word;
        } elsif ($c eq ')') {
            return $value;
        }
        if ($c eq "'") {
            $value .= $self->_get_rest_q_string();
        } elsif ($c eq '"') {
            $value .= $self->_get_rest_qq_string();
        } elsif ($c eq '`') {
            $value .= $self->_get_rest_qx_string();
        } elsif ($c eq '$') {
            if ($$target =~ /\G (\(\() /gcx) {
                $value .= $1 . $self->_get_rest_dbb_string();
            }
        }
    }

    $self->{current_line} = $self->{reader}->('token', '$(');
    die "Unexpected end of input" if !defined($self->{current_line});
    $value .= "\n" . $self->_get_rest_db_string();
    return $value;
}

sub _get_word {
    my ($self) = @_;
    my $target = \$self->{current_line};

    my $value = undef;

    while ($$target =~ /\G ([^\s<>()|;&]) /gcx) {
        $value //= "";

        my $c = $1;
        if ($c eq "'") {
            $value .= $c . $self->_get_rest_q_string();
        } elsif ($c eq '"') {
            $value .= $c . $self->_get_rest_qq_string();
        } elsif ($c eq '`') {
            $value .= $c . $self->_get_rest_qx_string();
        } elsif ($c eq '$') {
            if ($$target =~ /\G (\(\() /gcx) {
                $value .= $c . $1 . $self->_get_rest_dbb_string();
            } elsif ($$target =~ /\G (\() /gcx) {
                $value .= $c . $1 . $self->_get_rest_db_string();
            }
        } elsif ($c eq '\\') {
            if ($$target =~ /\G (.) /gcx) {
                $value .= $1;
            } else {
                $self->{current_line} = $self->{reader}->('token', '\\');
                die "Unexpected end of input" if !defined($self->{current_line});
                $target = \$self->{current_line};
            }
        } else {
            $value .= $c;
        }
    }

    return $value;
}

sub _get_next_token {
    my ($self) = @_;

    if (!defined($self->{current_line})) {
        $self->{current_line} = $self->{reader}->('new');
    }
    if (!defined($self->{current_line})) {
        return ('', undef);
    }

    my $target = \$self->{current_line};
    print "target: $$target\n";
    TOKEN: {
        if ($$target =~ /\G \n /gcx) {
            $self->{downgrade_assignment_word} = 0;
            return ('NEWLINE', '');
        }
        if ($$target =~ /\G (\#.*) /gcx) {
            $self->{downgrade_assignment_word} = 0;
            return ('NEWLINE', $1);
        }
        redo if $$target =~ /\G \s+ /gcx;

        foreach my $op (keys %operators) {
            if ($$target =~ /\G (\Q$op\E) /gcx) {
                if ($op eq ';;') {
                    $self->{case_state} = 3;
                }
                return ($operators{$op}, $1);
            }
        }

        my $word = $self->_get_word();
        if (defined($word)) {
            redo if $word eq "";

            if ($self->{for_state}) {
                $self->{for_state} = 0;
                return ('WORD', $word);
            }
            if ($self->{case_state} == 1) {
                $self->{case_state} = 2;
                return ('WORD', $word);
            }
            if ($self->{case_state} == 3) {
                if ($word eq 'esac') {
                    $self->{case_state} = 0;
                    return ('Esac', $word);
                }
                return ('WORD', $word);
            }

            if (!$self->{downgrade_assignment_word}) {
                foreach my $w (@reserved_words) {
                    if ($word eq $w) {
                        if ($w eq 'for') {
                            $self->{for_state} = 1;
                        } elsif ($w eq 'case') {
                            $self->{case_state} = 1;
                        } elsif ($w eq 'in') {
                            if ($self->{case_state} == 2) {
                                $self->{case_state} = 3;
                            }
                        } elsif ($w eq 'esac') {
                            die "unexpected esac";
                        }
                        return (uc(substr($w, 0, 1)) . substr($w, 1), $w);
                    }
                }

                return ('Lbrace', $word) if $word eq '{';
                return ('Rbrace', $word) if $word eq '}';
                return ('Bang',   $word) if $word eq '!';

                return ('ASSIGNMENT_WORD', $word) if ($word =~ /^[A-Za-z0-9]+=/);
            }

            $self->{downgrade_assignment_word} = 1;

            return ('WORD', $word);
            return ('UNKNOWN_WORD', $word);
        }

        $self->{downgrade_assignment_word} = 0;
        if ($self->{case_state} == 3 && $$target =~ /\G (\)) /gcx) {
            $self->{case_state} = 0;
            return ($1, $1);
        }
        return ($1, $1)       if $$target =~ /\G ([<>()|;&]) /gcx;

        return ('UNKNOWN', $1) if $$target =~ /\G (.) /gcx;

        $self->{current_line} = undef;
        return $self->_get_next_token();
    }
}

1;
