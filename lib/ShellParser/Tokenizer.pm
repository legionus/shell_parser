package ShellParser::Tokenizer;

use strict;
use warnings;

use ShellParser::Lexer;

use constant {
    STATE_NORMAL            => 0,
    STATE_COMMAND           => 1,
    STATE_WAIT_NAME         => 2,
    STATE_CASE_WAIT_WORD    => 3,
    STATE_CASE_WAIT_IN      => 4,
    STATE_CASE_WAIT_PATTERN => 5,
    STATE_ARRAY_WAIT_BRACE  => 6,
};

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
        lexer => ShellParser::Lexer->new($reader),
        state => STATE_NORMAL,
    };
    return bless($self, $class);
}

sub got_heredoc {
    my ($self, $delim, $accum_ref, $strip_tabs) = @_;
    $self->{lexer}->got_heredoc($delim, $accum_ref, $strip_tabs);
}

use ShellParser::Lexeme::QQString;
use ShellParser::Lexeme::Word;

sub _like_a_word {
    my ($self, $text) = @_;
    return $text =~ /^[^\s<>()|;&]/;
}

sub _get_sub_qq_string {
    my ($self, $head) = @_;

    $head //= $self->{lexer}->get_next_lexeme();
    return $head if !defined($head);

    if ($head->raw_string() eq '$') {
        my $name = $self->{lexer}->get_variable_name();
        if ($name eq '{') {
            my $content = "";
            while (my $token = $self->_get_sub_word()) {
                $content .= $token->raw_string();
                last if $token->raw_string() eq '}';
            }
            return ShellParser::Lexeme->new($head->raw_string() . $name . $content);
        } elsif ($name eq '(') {
            my $content = "";

            my $old_state = $self->{state};
            $self->{state} = STATE_NORMAL;

            my $prev_state = $self->{state};
            while (my ($token, $value) = $self->_get_next_token()) {
                if ($token eq '') {
                    die "Unexpected end of data";
                }
                # TODO(dmage): there shouldn't be two kind of values.
                if (ref($value) ne '') {
                    $value = $value->as_string();
                }
                $content .= $value;
                last if $prev_state == STATE_NORMAL && $value eq ')';
                $prev_state = $self->{state};
            }

            $self->{state} = $old_state;

            return ShellParser::Lexeme->new($head->raw_string() . $name . $content);
        } else {
            return ShellParser::Lexeme->new($head->raw_string() . $name);
        }
    }

    return $head;
}

sub _get_sub_word {
    my ($self, $head) = @_;

    $head //= $self->{lexer}->get_next_lexeme();
    return $head if !defined($head);

    if ($head->raw_string() eq '"') {
        my @qq_value_parts = ();
        my $str = "";
        while (1) {
            my $lexeme_obj = $self->_get_sub_qq_string();
            die "Unexpected end of \"...\" string" if !defined($lexeme_obj);
            last if $lexeme_obj->raw_string() eq '"';
            if (
                $lexeme_obj->isa("ShellParser::Lexeme::LineConcat") ||
                $lexeme_obj->isa("ShellParser::Lexeme::Escaped") ||
                $lexeme_obj->as_string() =~ /^\$/
            ) {
                push(@qq_value_parts, ShellParser::Lexeme->new($str)) if $str;
                $str = "";
                push(@qq_value_parts, $lexeme_obj);
            } else {
                $str .= $lexeme_obj->raw_string();
            }
        }
        push(@qq_value_parts, ShellParser::Lexeme->new($str)) if $str;
        return ShellParser::Lexeme::QQString->new(\@qq_value_parts);
    }

    return $self->_get_sub_qq_string($head);
}

sub _get_next_lexeme {
    my ($self) = @_;

    my $lexeme_obj = $self->{lexer}->get_next_lexeme();

    return $lexeme_obj if !defined($lexeme_obj);

    if ($self->_like_a_word($lexeme_obj->raw_string())) {
        my @value_parts = ($self->_get_sub_word($lexeme_obj));
        my $lookahead = $self->{lexer}->lookahead_direct();
        while ($self->_like_a_word($lookahead)) {
            $lexeme_obj = $self->_get_sub_word();
            last if !defined($lexeme_obj);
            push(@value_parts, $lexeme_obj);
            $lookahead = $self->{lexer}->lookahead_direct();
        }
        return ShellParser::Lexeme::Word->new(\@value_parts);
    }

    return $lexeme_obj;
}

sub _get_next_token {
    my ($self) = @_;

    my $lexeme_obj = $self->_get_next_lexeme();
    if (!defined($lexeme_obj)) {
        return ('', undef);
    }
    my $lexeme = $lexeme_obj->as_string();

    if ($lexeme eq "\n") {
        if ($self->{state} != STATE_CASE_WAIT_PATTERN) {
            $self->{state} = STATE_NORMAL;
        }
        return ('NEWLINE', $lexeme);
    }

    if ($lexeme =~ /^#/) {
        return ('BLANK', $lexeme)
    }
    if ($lexeme =~ /^\s*$/) {
        return ('BLANK', $lexeme)
    }

    foreach my $op (keys %operators) {
        if ($lexeme eq $op) {
            if ($op eq ';;') {
                $self->{state} = STATE_CASE_WAIT_PATTERN;
            }
            if ($op eq '||' || $op eq '&&') {
                if ($self->{state} == STATE_COMMAND) {
                    $self->{state} = STATE_NORMAL;
                }
            }
            return ($operators{$op}, $lexeme);
        }
    }

    if ($lexeme =~ /^[<>()|;&]$/) {
        if ($self->{state} == STATE_ARRAY_WAIT_BRACE) {
            $self->{state} = STATE_COMMAND;
        } else {
            $self->{state} = STATE_NORMAL;
        }
        return ($lexeme, $lexeme);
    }

    if ($self->{state} == STATE_NORMAL) {
        if ($lexeme =~ /^[0-9]+$/) {
            my $next = $self->{lexer}->lookahead();
            if ($next eq '<' or $next eq '>') {
                return ('IO_NUMBER', $lexeme);
            }
        }

        foreach my $w (@reserved_words) {
            if ($lexeme eq $w) {
                if ($w eq 'for') {
                    $self->{state} = STATE_WAIT_NAME;
                } elsif ($w eq 'case') {
                    $self->{state} = STATE_CASE_WAIT_WORD;
                }
                return (uc(substr($w, 0, 1)) . substr($w, 1), $w);
            }
        }

        return ('Lbrace', $lexeme) if $lexeme eq '{';
        return ('Rbrace', $lexeme) if $lexeme eq '}';
        return ('Bang',   $lexeme) if $lexeme eq '!';

        my $next = $self->{lexer}->lookahead_direct();
        if ($next eq '(' && $lexeme =~ /^[A-Za-z0-9_]+\+?=/) {
            $self->{state} = STATE_ARRAY_WAIT_BRACE;
            return ('ASSIGNMENT_WORD_ARRAY', $lexeme_obj);
        } elsif ($lexeme =~ /^[A-Za-z0-9_]+=/) {
            return ('ASSIGNMENT_WORD', $lexeme_obj);
        }

        $self->{state} = STATE_COMMAND;
        return ('WORD', $lexeme_obj);
    } elsif ($self->{state} == STATE_COMMAND) {
        if ($lexeme =~ /^[0-9]+$/) {
            my $next = $self->{lexer}->lookahead();
            if ($next eq '<' or $next eq '>') {
                return ('IO_NUMBER', $lexeme);
            }
        }
        return ('WORD', $lexeme_obj);
    } elsif ($self->{state} == STATE_WAIT_NAME) {
        $self->{state} = STATE_NORMAL;
        return ('WORD', $lexeme_obj);
    } elsif ($self->{state} == STATE_CASE_WAIT_WORD) {
        $self->{state} = STATE_CASE_WAIT_IN;
        return ('WORD', $lexeme_obj);
    } elsif ($self->{state} == STATE_CASE_WAIT_IN) {
        if ($lexeme ne 'in') {
            die "Expected 'in', got '$lexeme'";
        }
        $self->{state} = STATE_CASE_WAIT_PATTERN;
        return ('In', $lexeme);
    } elsif ($self->{state} == STATE_CASE_WAIT_PATTERN) {
        if ($lexeme eq 'esac') {
            $self->{state} = STATE_NORMAL;
            return ('Esac', $lexeme);
        }
        return ('WORD', $lexeme_obj);
    } else {
        die "Unexpected state: $self->{state}";
    }

    die "Unreachable code";
}

1;
