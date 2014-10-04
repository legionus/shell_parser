package ShellParser::Lexer;

use strict;
use warnings;

use ShellParser::Lexeme;
use ShellParser::Lexeme::Escaped;
use ShellParser::Lexeme::LineConcat;
use ShellParser::Lexeme::QQString;
use ShellParser::Lexeme::QString;
use ShellParser::Lexeme::Word;

my @operators = qw(
    &&
    ;;
    ||
    >&
    >|
    >>
    <&
    <>
    <<-
    <<
);

our $name_re = '(?:[A-Za-z0-9_]+|[$@])';

sub new {
    my ($class, $reader) = @_;
    my $self = {
        reader => $reader,
        heredoc => [],
    };
    return bless($self, $class);
}

sub _get_rest_variable {
    my ($self) = @_;
    my $target = \$self->{current_line};

    my $value = "";
    while ($$target =~ /\G (\\$) /gcx) {
        $self->{current_line} = $self->{reader}->('token', '$...');
        die "Unexpected end of input while scanning \$... string" if !defined($self->{current_line});
    }
    if ($$target =~ /\G (\() /gcx) {
        $value .= $1;
        $value .= $self->_get_rest_b_string();
        return $value;
    }
    if ($$target =~ /\G ({) /gcx) {
        $value .= $1;
        $value .= $self->_get_rest_c_string();
        return $value;
    }
    while (1) {
        if ($$target =~ /\G ($name_re) /gcx) {
            $value .= $1;
        } elsif ($$target =~ /\G (\\$) /gcx) {
            $self->{current_line} = $self->{reader}->('token', '$...');
            die "Unexpected end of input while scanning \$... string" if !defined($self->{current_line});
        } else {
            return $value;
        }
    }

    die "Unreachable code";
}

sub _get_q_string {
    my ($self) = @_;
    my $target = \$self->{current_line};

    my $value = "";
    while (1) {
        $$target =~ /\G ([^']*'|.*) /gcx;
        $value .= $1;
        if ($value =~ /'$/) {
            $value =~ s/'$//;
            return ShellParser::Lexeme::QString->new($value);
        }

        $self->{current_line} = $self->{reader}->('token', "'");
        die "Unexpected end of input while scanning '...' string" if !defined($self->{current_line});
        $value .= "\n";
    }

    die "Unreachable code";
}

sub _get_qq_string {
    my ($self) = @_;
    my $target = \$self->{current_line};

    my @value_parts;
    while (1) {
        if ($$target =~ /\G (.) /gcx) {
            my $c = $1;

            if ($c eq '"') {
                return ShellParser::Lexeme::QQString->new(\@value_parts);
            } elsif ($c eq '$') {
                push(@value_parts, ShellParser::Lexeme->new($c . $self->_get_rest_variable()));
            } elsif ($c eq '\\') {
                if ($$target =~ /\G (.) /gcx) {
                    push(@value_parts, ShellParser::Lexeme::Escaped->new($1));
                } else {
                    $self->{current_line} = $self->{reader}->('token', '"');
                    die "Unexpected end of input while scanning \"...\" string" if !defined($self->{current_line});
                    push(@value_parts, ShellParser::Lexeme::LineConcat->new());
                }
            } else {
                # FIXME
                my $prev_part = $value_parts[-1];
                if ($prev_part && $prev_part->{_simple_lexeme}) {
                    $prev_part->{value} .= $c;
                } else {
                    my $lexeme = ShellParser::Lexeme->new($c);
                    $lexeme->{_simple_lexeme} = 1;
                    push(@value_parts, $lexeme);
                }
            }
        } else {
            $self->{current_line} = $self->{reader}->('token', '"');
            die "Unexpected end of input while scanning \"...\" string" if !defined($self->{current_line});

            # FIXME
            my $prev_part = $value_parts[-1];
            if ($prev_part && $prev_part->{_simple_lexeme}) {
                $prev_part->{value} .= "\n";
            } else {
                my $lexeme = ShellParser::Lexeme->new("\n");
                $lexeme->{_simple_lexeme} = 1;
                push(@value_parts, $lexeme);
            }
        }
    }

    die "Unreachable code";
}

sub _get_rest_qx_string {
    my ($self) = @_;
    my $target = \$self->{current_line};

    my $value = "";
    while (1) {
        $$target =~ /\G ([^`]*`|.*) /gcx;
        $value .= $1;
        if ($value =~ /`$/) {
            return $value;
        }

        $self->{current_line} = $self->{reader}->('token', '`');
        die "Unexpected end of input while scanning `...` string" if !defined($self->{current_line});
        $value .= "\n";
    }

    die "Unreachable code";
}

sub _get_rest_c_string {
    my ($self) = @_;
    my $target = \$self->{current_line};

    my $value = "";
    while (1) {
        if ($$target =~ /\G (.) /gcx) {
            my $c = $1;

            if ($c eq '}') {
                return $value . $c;
            } elsif ($c eq "'") {
                $value .= $self->_get_q_string()->raw_string();  # FIXME
            } elsif ($c eq '"') {
                $value .= $self->_get_qq_string()->raw_string();  # FIXME
            } elsif ($c eq '\\') {
                if ($$target =~ /\G (.) /gcx) {
                    $value .= $c . $1;
                } else {
                    $self->{current_line} = $self->{reader}->('token', '${');
                    die "Unexpected end of input while scanning \${...} string" if !defined($self->{current_line});
                    $value .= $c . "\n";
                }
            } else {
                $value .= $c;
            }
        } else {
            $self->{current_line} = $self->{reader}->('token', '${');
            die "Unexpected end of input while scanning \${...} string" if !defined($self->{current_line});
            $value .= "\n";
        }
    }

    die "Unreachable code";
}

sub _get_rest_b_string {
    my ($self) = @_;
    my $target = \$self->{current_line};

    my $value = "";
    while (1) {
        my $word = $self->_get_word();
        if (defined($word)) {
            $value .= $word->as_string();  # FIXME
        } elsif ($$target =~ /\G (.) /gcx) {
            my $c = $1;

            if ($c eq ')') {
                return $value . $c;
            } elsif ($c eq "'") {
                $value .= $self->_get_q_string()->raw_string();  # FIXME
            } elsif ($c eq '"') {
                $value .= $self->_get_qq_string()->raw_string();  # FIXME
            } elsif ($c eq '`') {
                $value .= $c . $self->_get_rest_qx_string();
            } elsif ($c eq '$') {
                $value .= $c . $self->_get_rest_variable();
            } elsif ($c eq '(') {
                $value .= $c . $self->_get_rest_b_string();
            } else {
                $value .= $c;
            }
        } else {
            $self->{current_line} = $self->{reader}->('token', '$(');
            die "Unexpected end of input while scanning \$(...) string" if !defined($self->{current_line});
            $value .= "\n";
        }
    }

    die "Unreachable code";
}

sub _get_word_part {
    my ($self) = @_;
    my $target = \$self->{current_line};

    my @value_parts;

    if ($$target =~ /\G ([^\s<>()|;&]) /gcx) {
        my $c = $1;
        if ($c eq "'") {
            return $self->_get_q_string();
        } elsif ($c eq '"') {
            return ShellParser::Lexeme->new($c);
        } elsif ($c eq '`') {
            return ShellParser::Lexeme->new($c . $self->_get_rest_qx_string());
        } elsif ($c eq '$') {
            return ShellParser::Lexeme->new($c . $self->_get_rest_variable());
        } elsif ($c eq '\\') {
            if ($$target =~ /\G (.) /gcx) {
                return ShellParser::Lexeme::Escaped->new($1);
            } else {
                $self->{current_line} = $self->{reader}->('token', '\\');
                die "Unexpected end of input" if !defined($self->{current_line});
                return ShellParser::Lexeme::LineConcat->new();
            }
        } elsif ($$target =~ /\G ([^\s<>()|;&'"`\$\\]+) /gcx) {
            return ShellParser::Lexeme->new($c . $1);
        } else {
            return ShellParser::Lexeme->new($c);
        }
    }

    return;
}

sub _get_word {
    my ($self) = @_;
    my $target = \$self->{current_line};

    my @value_parts;

    while ($$target =~ /\G ([^\s<>()|;&]) /gcx) {
        my $c = $1;
        if ($c eq "'") {
            push(@value_parts, $self->_get_q_string());
        } elsif ($c eq '"') {
            push(@value_parts, $self->_get_qq_string());
        } elsif ($c eq '`') {
            push(@value_parts, ShellParser::Lexeme->new($c . $self->_get_rest_qx_string()));
        } elsif ($c eq '$') {
            push(@value_parts, ShellParser::Lexeme->new($c . $self->_get_rest_variable()));
        } elsif ($c eq '\\') {
            if ($$target =~ /\G (.) /gcx) {
                push(@value_parts, ShellParser::Lexeme::Escaped->new($1));
            } else {
                push(@value_parts, ShellParser::Lexeme::LineConcat->new());
                $self->{current_line} = $self->{reader}->('token', '\\');
                die "Unexpected end of input" if !defined($self->{current_line});
                $target = \$self->{current_line};
            }
        } else {
            # FIXME
            my $prev_part = $value_parts[-1];
            if ($prev_part && $prev_part->{_simple_lexeme}) {
                $prev_part->{value} .= $c;
            } else {
                my $lexeme = ShellParser::Lexeme->new($c);
                $lexeme->{_simple_lexeme} = 1;
                push(@value_parts, $lexeme);
            }
        }
    }

    if (@value_parts != 0) {
        return ShellParser::Lexeme::Word->new(\@value_parts);
    } else {
        return;
    }
}

sub _get_heredoc {
    my ($self, $heredoc_desc) = @_;
    my $delim = $heredoc_desc->{delim}->dequote();
    my $accum_ref = $heredoc_desc->{accum_ref};
    my $strip_tabs = $heredoc_desc->{strip_tabs};

    while (1) {
        my $line = $self->{reader}->('HEREDOC:' . $delim);
        if (!defined($line)) {
            die "Unexpected end of here-document ($delim)";
        }
        chomp($line);
        if ($strip_tabs) {
            $line =~ s/^\t+//;
        }
        if ($line eq $delim) {
            return;
        }
        $accum_ref .= "$line\n";
    }
}

sub got_heredoc {
    my ($self, $delim, $accum_ref, $strip_tabs) = @_;
    push(
        @{$self->{heredoc}},
        {
            delim => $delim,
            accum_ref => $accum_ref,
            strip_tabs => $strip_tabs,
        }
    );
}

sub get_next_lexeme {
    my ($self) = @_;

    if (!defined($self->{current_line})) {
        while (@{$self->{heredoc}} != 0) {
            my $heredoc_desc = shift(@{$self->{heredoc}});
            $self->_get_heredoc($heredoc_desc);
        }
        $self->{current_line} = $self->{reader}->('new');
    }
    if (!defined($self->{current_line})) {
        return undef;
    }

    my $target = \$self->{current_line};
    TOKEN: {
        return ShellParser::Lexeme->new($1) if $$target =~ /\G (\n)   /gcx;
        return ShellParser::Lexeme->new($1) if $$target =~ /\G (\#.*) /gcx;
        return ShellParser::Lexeme->new($1) if $$target =~ /\G ([ \t]+)  /gcx;

        foreach my $q (@operators) {
            return ShellParser::Lexeme->new($1) if ($$target =~ /\G (\Q$q\E) /gcx);
        }

        my $word_part = $self->_get_word_part();
        if (defined($word_part)) {
            return $word_part;
        }

        return ShellParser::Lexeme->new($1) if $$target =~ /\G (.) /gcx;

        $self->{current_line} = undef;
        return $self->get_next_lexeme();
    }
}

sub lookahead {
    my ($self) = @_;
    if ($self->{current_line} =~ /\G \s*(.) /x) {
        return $1;
    } else {
        return '';
    }
}

sub lookahead_direct {
    my ($self) = @_;
    if ($self->{current_line} =~ /\G (.) /x) {
        return $1;
    } else {
        return '';
    }
}

1;
