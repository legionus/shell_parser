package Lexer;

use strict;
use warnings;

my @operators = qw(
    &&
    ||
    ;;
    <<
    >>
    <&
    >&
    <>
    <<-
    >|
);

sub new {
    my ($class, $reader) = @_;
    my $self = {
        reader => $reader,
        lookahead_value => undef,
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
        $value .= "\n" . $self->_get_rest_qx_string();
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
        if ($c =~ /[^\s<>()|;&]/) {
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

sub get_next_lexem {
    my ($self) = @_;

    if (!defined($self->{current_line})) {
        $self->{current_line} = $self->{reader}->('new');
    }
    if (!defined($self->{current_line})) {
        return undef;
    }

    my $target = \$self->{current_line};
    TOKEN: {
        return $1 if $$target =~ /\G (\n)   /gcx;
        return $1 if $$target =~ /\G (\#.*) /gcx;
        return $1 if $$target =~ /\G (\s+)  /gcx;

        foreach my $q (@operators) {
            return $1 if ($$target =~ /\G (\Q$q\E) /gcx);
        }

        my $word = $self->_get_word();
        if (defined($word)) {
            return $word;
        }

        return ($1, $1) if $$target =~ /\G (.) /gcx;

        $self->{current_line} = undef;
        return $self->get_next_lexem();
    }
}

1;
