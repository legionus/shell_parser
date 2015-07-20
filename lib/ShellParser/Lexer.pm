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

sub get_q_string {
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

sub get_variable_name {
    my ($self) = @_;
    my $target = \$self->{current_line};

    while ($$target =~ /\G (\\$) /gcx) {
        $self->{current_line} = $self->{reader}->('token', '$...');
        die "Unexpected end of input while scanning variable name" if !defined($self->{current_line});
    }

    if ($$target =~ /\G (\(\(?) /gcx) {
        return $1;
    }

    if ($$target =~ /\G ([^\s<>()|;&`]) /gcx) {
        my $value = $1;
        if ($value =~ /^[A-Za-z_]$/) {
            while (1) {
                if ($$target =~ /\G ([A-Za-z0-9_]+) /gcx) {
                    $value .= $1;
                } elsif ($$target =~ /\G (\\$) /gcx) {
                    $self->{current_line} = $self->{reader}->('token', '$...');
                    die "Unexpected end of input while scanning variable name" if !defined($self->{current_line});
                } else {
                    return $value;
                }
            }
        }
        return $value;
    }

    return "";
}

sub _get_word_part {
    my ($self) = @_;
    my $target = \$self->{current_line};

    my @value_parts;

    if ($$target =~ /\G ([^\s<>()|;&]) /gcx) {
        my $c = $1;
        if ($c eq "'") {
            return ShellParser::Lexeme->new($c);
        } elsif ($c eq '"') {
            return ShellParser::Lexeme->new($c);
        } elsif ($c eq '`') {
            return ShellParser::Lexeme->new($c);
        } elsif ($c eq '$') {
            return ShellParser::Lexeme->new($c);
        } elsif ($c eq '\\') {
            if ($$target =~ /\G (.) /gcx) {
                return ShellParser::Lexeme::Escaped->new($1);
            } else {
                $self->{current_line} = $self->{reader}->('token', '\\');
                die "Unexpected end of input" if !defined($self->{current_line});
                return ShellParser::Lexeme::LineConcat->new();
            }
        } elsif ($c =~ /^[^\s<>()|;&'"`\$\\{}]$/ && $$target =~ /\G ([^\s<>()|;&'"`\$\\{}]+) /gcx) {
            return ShellParser::Lexeme->new($c . $1);
        } else {
            return ShellParser::Lexeme->new($c);
        }
    }

    return;
}

sub _get_heredoc {
    my ($self, $r) = @_;
    my $delim = $r->{here_end}->dequote();

    while (1) {
        my $line = $self->{reader}->('HEREDOC:' . $delim);
        if (!defined($line)) {
            die "Unexpected end of here-document ($delim)";
        }
        chomp($line);
        if ($line eq $delim) {
            return;
        }
        push(@{$r->{lines}}, ShellParser::Lexeme->new($line));
    }
}

sub got_heredoc {
    my ($self, $r) = @_;
    push(@{$self->{heredoc}}, $r);
}

sub get_next_lexeme {
    my ($self, $ignore_comments) = @_;

    if (!defined($self->{current_line})) {
        while (@{$self->{heredoc}} != 0) {
            my $r = shift(@{$self->{heredoc}});
            $self->_get_heredoc($r);
        }
        $self->{current_line} = $self->{reader}->('new');
    }
    if (!defined($self->{current_line})) {
        return undef;
    }

    my $target = \$self->{current_line};
    TOKEN: {
        if ($ignore_comments) {
            return ShellParser::Lexeme->new($1) if $$target =~ /\G (\#) /gcx;
        } else {
            return ShellParser::Lexeme->new($1) if $$target =~ /\G (\#.*) /gcx;
        }

        return ShellParser::Lexeme->new($1) if $$target =~ /\G (\n) /gcx;
        return ShellParser::Lexeme->new($1) if $$target =~ /\G ([ \t]+) /gcx;

        foreach my $q (@operators) {
            return ShellParser::Lexeme->new($1) if ($$target =~ /\G (\Q$q\E) /gcx);
        }

        my $word_part = $self->_get_word_part();
        if (defined($word_part)) {
            return $word_part;
        }

        return ShellParser::Lexeme->new($1) if $$target =~ /\G (.) /gcx;

        $self->{current_line} = undef;
        return $self->get_next_lexeme($ignore_comments);
    }
}

sub lookahead {
    my ($self) = @_;
    if ($self->{current_line} =~ /\G \s* (.) /x) {
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
