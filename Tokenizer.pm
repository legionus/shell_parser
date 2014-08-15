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

    my $lexem = $self->{lexer}->get_next_lexem();
    if (!defined($lexem)) {
        return ('', undef);
    }

    if ($lexem eq "\n") {
        $self->{downgrade_assignment_word} = 0;
        return ('NEWLINE', '');
    }
    if ($lexem =~ /^#/) {
        $self->{downgrade_assignment_word} = 0;
        return ('NEWLINE', $lexem);
    }
    if ($lexem =~ /^\s+$/) {
        return $self->_get_next_token();
    }

    foreach my $op (keys %operators) {
        if ($lexem eq $op) {
            if ($op eq ';;') {
                $self->{case_state} = 3;
            }
            return ($operators{$op}, $lexem);
        }
    }

    if ($lexem =~ /^[<>()|;&]$/) {
        $self->{downgrade_assignment_word} = 0;
        if ($self->{case_state} == 3 && $lexem eq ')') {
            $self->{case_state} = 0;
            return ($lexem, $lexem);
        }
        return ($lexem, $lexem);
    }

    if ($self->{for_state}) {
        $self->{for_state} = 0;
        return ('WORD', $lexem);
    }
    if ($self->{case_state} == 1) {
        $self->{case_state} = 2;
        return ('WORD', $lexem);
    }
    if ($self->{case_state} == 3) {
        if ($lexem eq 'esac') {
            $self->{case_state} = 0;
            return ('Esac', $lexem);
        }
        return ('WORD', $lexem);
    }

    if (!$self->{downgrade_assignment_word}) {
        foreach my $w (@reserved_words) {
            if ($lexem eq $w) {
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

        return ('Lbrace', $lexem) if $lexem eq '{';
        return ('Rbrace', $lexem) if $lexem eq '}';
        return ('Bang',   $lexem) if $lexem eq '!';

        return ('ASSIGNMENT_WORD', $lexem) if ($lexem =~ /^[A-Za-z0-9]+=/);
    }

    $self->{downgrade_assignment_word} = 1;

    return ('WORD', $lexem);
}

1;
