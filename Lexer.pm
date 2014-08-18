package Lexer;

use strict;
use warnings;

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

sub new {
    my ($class, $reader) = @_;
    my $self = {
        reader => $reader,
        heredoc => [],
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
            if ($$target =~ /\G (\() /gcx) {
                $value .= $1 . $self->_get_rest_b_string();
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

    while (1) {
        $$target =~ /\G ([^`]*`|.*) /gcx;
        $value = $1;
        if ($value =~ /`$/) {
            return $value;
        }

        # FIXME: handle \", etc.
        $self->{current_line} = $self->{reader}->('token', '`');
        die "Unexpected end of input" if !defined($self->{current_line});
        $value .= "\n";
    }

    die "Unreachable code";
}

sub _get_rest_c_string {
    my ($self) = @_;
    my $target = \$self->{current_line};

    my $value = "";

    $$target =~ /\G ([^}]*}|.*) /gcx;
    $value = $1;
    if ($value !~ /}$/) {
        # FIXME: ???
        $self->{current_line} = $self->{reader}->('token', '}');
        die "Unexpected end of input" if !defined($self->{current_line});
        $value .= "\n" . $self->_get_rest_c_string();
    }

    return $value;
}

sub _get_rest_b_string
{
    my ($self) = @_;
    my $target = \$self->{current_line};

    my $value = "";

    while (1) {
        my $word = $self->_get_word();
        if (defined($word)) {
            $value .= $word;
        } elsif ($$target =~ /\G (.) /gcx) {
            my $c = $1;
            $value .= $c;
            if ($c eq ')') {
                return $value;
            } elsif ($c eq "'") {
                $value .= $self->_get_rest_q_string();
            } elsif ($c eq '"') {
                $value .= $self->_get_rest_qq_string();
            } elsif ($c eq '`') {
                $value .= $self->_get_rest_qx_string();
            } elsif ($c eq '$') {
                if ($$target =~ /\G (\() /gcx) {
                    $value .= $1 . $self->_get_rest_b_string();
                } elsif ($$target =~ /\G ({) /gcx) {
                    $value .= $1 . $self->_get_rest_c_string();
                }
            } elsif ($c eq '(') {
                $value .= $self->_get_rest_b_string();
            }
        } else {
            last;
        }
    }

    $self->{current_line} = $self->{reader}->('token', '$(');
    die "Unexpected end of input" if !defined($self->{current_line});
    $value .= "\n" . $self->_get_rest_b_string();
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
            if ($$target =~ /\G (\() /gcx) {
                $value .= $c . $1 . $self->_get_rest_b_string();
            } elsif ($$target =~ /\G ({) /gcx) {
                $value .= $c . $1 . $self->_get_rest_c_string();
            } else {
                $value .= $c;
            }
        } elsif ($c eq '\\') {
            if ($$target =~ /\G (.) /gcx) {
                $value .= $c . $1;
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

sub _get_heredoc {
    my ($self, $heredoc_desc) = @_;
    my $delim = $heredoc_desc->{delim};
    my $accum_ref = $heredoc_desc->{accum_ref};
    my $strip_tabs = $heredoc_desc->{strip_tabs};

    # FIXME
    if ($delim =~ /^'(.*)'$/) {
        $delim = $1;
    } elsif ($delim =~ /^"(.*)"$/) {
        $delim = $1;
    }

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
        return $1 if $$target =~ /\G (\n)   /gcx;
        return $1 if $$target =~ /\G (\#.*) /gcx;
        return $1 if $$target =~ /\G ([ \t]+)  /gcx;

        foreach my $q (@operators) {
            return $1 if ($$target =~ /\G (\Q$q\E) /gcx);
        }

        my $word = $self->_get_word();
        if (defined($word)) {
            return $word;
        }

        return ($1, $1) if $$target =~ /\G (.) /gcx;

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

1;
