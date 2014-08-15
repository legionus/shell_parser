package Tokenizer;

use strict;
use warnings;

use Lexer;

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
        lexer => Lexer->new($reader),
        state => {},
        for_state => 0,
        case_state => 0,
        downgrade_assignment_word => 0,
    };
    return bless($self, $class);
}

sub _get_next_token {
    my ($self) = @_;

    my $lexeme = $self->{lexer}->get_next_lexeme();
    if (!defined($lexeme)) {
        return ('', undef);
    }

    if ($lexeme eq "\n") {
        $self->{downgrade_assignment_word} = 0;
        return ('NEWLINE', '');
    }
    if ($lexeme =~ /^#/) {
        $self->{downgrade_assignment_word} = 0;
        return ('NEWLINE', $lexeme);
    }
    if ($lexeme =~ /^\s+$/) {
        return $self->_get_next_token();
    }

    foreach my $op (keys %operators) {
        if ($lexeme eq $op) {
            if ($op eq ';;') {
                $self->{case_state} = 3;
            }
            return ($operators{$op}, $lexeme);
        }
    }

    if ($lexeme =~ /^[<>()|;&]$/) {
        $self->{downgrade_assignment_word} = 0;
        if ($self->{case_state} == 3 && $lexeme eq ')') {
            $self->{case_state} = 0;
            return ($lexeme, $lexeme);
        }
        return ($lexeme, $lexeme);
    }

    if ($self->{for_state}) {
        $self->{for_state} = 0;
        return ('WORD', $lexeme);
    }
    if ($self->{case_state} == 1) {
        $self->{case_state} = 2;
        return ('WORD', $lexeme);
    }
    if ($self->{case_state} == 3) {
        if ($lexeme eq 'esac') {
            $self->{case_state} = 0;
            return ('Esac', $lexeme);
        }
        return ('WORD', $lexeme);
    }

    if (!$self->{downgrade_assignment_word}) {
        foreach my $w (@reserved_words) {
            if ($lexeme eq $w) {
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

        return ('Lbrace', $lexeme) if $lexeme eq '{';
        return ('Rbrace', $lexeme) if $lexeme eq '}';
        return ('Bang',   $lexeme) if $lexeme eq '!';

        return ('ASSIGNMENT_WORD', $lexeme) if ($lexeme =~ /^[A-Za-z0-9]+=/);
    }

    $self->{downgrade_assignment_word} = 1;

    return ('WORD', $lexeme);
}

1;
