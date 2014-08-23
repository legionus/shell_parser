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

sub _get_next_token {
    my ($self) = @_;

    my $lexeme_obj = $self->{lexer}->get_next_lexeme();
    if (!defined($lexeme_obj)) {
        return ('', undef);
    }
    my $lexeme = $lexeme_obj->as_string();

    if ($lexeme eq "\n") {
        if ($self->{state} != STATE_CASE_WAIT_PATTERN) {
            $self->{state} = STATE_NORMAL;
        }
        return ('NEWLINE', '');
    }

    if ($lexeme =~ /^#/) {
        return $self->_get_next_token();
    }
    if ($lexeme =~ /^\s*$/) {
        return $self->_get_next_token();
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

        if ($lexeme =~ /^[A-Za-z0-9_]+=/) {
            my $next = $self->{lexer}->lookahead_direct();
            if ($next eq '(') {
                $self->{state} = STATE_ARRAY_WAIT_BRACE;
                return ('ASSIGNMENT_WORD_ARRAY', $lexeme_obj);
            } else {
                return ('ASSIGNMENT_WORD', $lexeme_obj);
            }
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
