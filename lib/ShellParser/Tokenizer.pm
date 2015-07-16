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

use ShellParser::Lexeme::QQString;
use ShellParser::Lexeme::Word;
use ShellParser::Lexeme::CommandSubstitution;
use ShellParser::Lexeme::HereDoc;

sub _like_a_word {
    my ($self, $text) = @_;
    return $text =~ /^[^\s<>()|;&]/;
}

sub _get_variable {
    my ($self, $head) = @_;

    my $name = $self->{lexer}->get_variable_name();

    if ($name eq '{') {
        my $content = "";
        while (1) {
            my $token = $self->_get_word_part();
            if (!defined($token)) {
                die "Expected '}', got EOF";
            }
            $content .= $token->raw_string();
            last if $token->raw_string() eq '}';
        }
        return ShellParser::Lexeme->new($head->raw_string() . $name . $content);
    }

    if ($name eq '((') {
        my $content = "";
        my $depth = 2;
        while (1) {
            my $token = $self->_get_word_part();
            if (!defined($token)) {
                die "Expected ')', got EOF";
            }
            $content .= $token->raw_string();
            $depth += 1 if $token->raw_string() eq '(';
            $depth -= 1 if $token->raw_string() eq ')';
            last if $depth == 0;
        }
        return ShellParser::Lexeme->new($head->raw_string() . $name . $content);
    }

    if ($name eq '(') {
        my @value_parts;
        my $old_state = $self->{state};
        $self->{state} = STATE_NORMAL;
        my $prev_state = $self->{state};
        while (my ($token, $value) = $self->_get_next_token()) {
            if ($token eq '') {
                die "Expected ')', got EOF";
            }
            # TODO(dmage): there shouldn't be two kind of values.
            if (ref($value) eq '') {
                $value = ShellParser::Lexeme->new($value);
            }
            last if ($prev_state == STATE_NORMAL || $prev_state == STATE_COMMAND) && $value->raw_string() eq ')';
            push(@value_parts, [$token, $value]);
            $prev_state = $self->{state};
        }
        $self->{state} = $old_state;
        return ShellParser::Lexeme::CommandSubstitution->new(\@value_parts);
    }

    return ShellParser::Lexeme->new($head->raw_string() . $name);
}

sub _get_backquoted {
    my ($self, $head) = @_;

    my $content = "";
    while (1) {
        my $token = $self->{lexer}->get_next_lexeme();
        if (!defined($token)) {
            die "Expected '`', got EOF";
        }
        $content .= $token->raw_string();
        last if $token->raw_string() eq '`';
    }
    return ShellParser::Lexeme->new($head->raw_string() . $content);
}

sub _get_qq_string_part {
    my ($self, $head) = @_;

    $head //= $self->{lexer}->get_next_lexeme(1);
    return $head if !defined($head);

    if ($head->raw_string() eq '$') {
        return $self->_get_variable($head);
    }

    if ($head->raw_string() eq '`') {
        return $self->_get_backquoted($head);
    }

    return $head;
}

sub _get_word_part {
    my ($self, $head) = @_;

    $head //= $self->{lexer}->get_next_lexeme();
    return $head if !defined($head);

    if ($head->raw_string() eq '"') {
        my @qq_value_parts = ();
        my $str = "";
        while (1) {
            my $lexeme_obj = $self->_get_qq_string_part();
            if (!defined($lexeme_obj)) {
                die "Expected '\"', got EOF";
            }
            last if $lexeme_obj->raw_string() eq '"';
            if (
                $lexeme_obj->isa("ShellParser::Lexeme::LineConcat") ||
                $lexeme_obj->isa("ShellParser::Lexeme::Escaped") ||
                $lexeme_obj->isa("ShellParser::Lexeme::CommandSubstitution") ||
                $lexeme_obj->as_string() =~ /^\$/
            ) {
                push(@qq_value_parts, ShellParser::Lexeme->new($str)) if $str;
                $str = "";
                push(@qq_value_parts, $lexeme_obj);
            } else {
                # TODO(dmage): ugly hack to minimize tree size
                $str .= $lexeme_obj->raw_string();
            }
        }
        push(@qq_value_parts, ShellParser::Lexeme->new($str)) if $str;
        return ShellParser::Lexeme::QQString->new(\@qq_value_parts);
    }

    if ($head->raw_string() eq "'") {
        return $self->{lexer}->get_q_string();
    }

    if ($head->raw_string() eq '$') {
        return $self->_get_variable($head);
    }

    if ($head->raw_string() eq '`') {
        return $self->_get_backquoted($head);
    }

    return $head;
}

sub _get_next_lexeme {
    my ($self) = @_;

    my $lexeme_obj = $self->{lexer}->get_next_lexeme();

    return $lexeme_obj if !defined($lexeme_obj);

    if ($self->_like_a_word($lexeme_obj->raw_string())) {
        my @value_parts = ($self->_get_word_part($lexeme_obj));
        my $lookahead = $self->{lexer}->lookahead_direct();
        while ($self->_like_a_word($lookahead)) {
            $lexeme_obj = $self->_get_word_part();
            last if !defined($lexeme_obj);
            push(@value_parts, $lexeme_obj);
            $lookahead = $self->{lexer}->lookahead_direct();
        }
        return ShellParser::Lexeme::Word->new(\@value_parts);
    }

    return $lexeme_obj;
}

sub _get_next_non_blank_token {
    my ($self) = @_;
    while (1) {
        my ($token, $value) = $self->_get_next_token();
        return ($token, $value) if $token ne 'BLANK';
    }
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
        return ('COMMENT', $lexeme)
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
            if ($op eq '<<' || $op eq '<<-') {
                my ($type, $here_end) = $self->_get_next_non_blank_token();
                if ($type ne 'WORD') {
                    die "Expected WORD, got $type";
                }

                my $strip_tabs = ($op eq '<<-') + 0;
                my $r = ShellParser::Lexeme::HereDoc->new($op, $here_end, $strip_tabs);
                $self->{lexer}->got_heredoc($r);
                return ('IO_HERE', $r)
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
