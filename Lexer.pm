package Lexer;

use strict;
use warnings;

my @reserved_words = qw(if then else elif fi done do case esac while until for in);

sub new {
    my ($class, $reader) = @_;
    my $self = {
        state => {},
        reader => $reader,
        prev_token => '',
        inject => undef,
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

    $$target =~ /\G ([^"]*"|.*) /gcx;
    $value = $1;
    if ($value !~ /"$/) {
        # FIXME: handle \", etc.
        $self->{current_line} = $self->{reader}->('token', '"');
        die "Unexpected end of input" if !defined($self->{current_line});
        $value .= "\n" . $self->_get_rest_qq_string();
    }

    return $value;
}
sub _get_word {
    my ($self) = @_;
    my $target = \$self->{current_line};

    my $value = "";

    print "target: $$target\n";
    while ($$target =~ /\G ([^\s<>()|;&]) /gcx) {
        my $c = $1;
        $value .= $c;
        if ($c eq "'") {
            $value .= $self->_get_rest_q_string();
        } elsif ($c eq '"') {
            $value .= $self->_get_rest_qq_string();
        }
        print "word: $value\n";
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

    my $prev_token = $self->{prev_token};
    $self->{prev_token} = '';

    my $inject = $self->{inject};
    $self->{inject} = undef;
    if ($inject) {
        return @$inject;
    }

    my $target = \$self->{current_line};
    TOKEN: {
        return ('NEWLINE', '') if $$target =~ /\G \n     /gcx;
        return ('NEWLINE', $1) if $$target =~ /\G (\#.*) /gcx;
        redo                   if $$target =~ /\G \s+    /gcx;

        return ('AND_IF',    $1) if $$target =~ /\G (&&)   /gcx;
        return ('OR_IF',     $1) if $$target =~ /\G (\|\|) /gcx;
        return ('DSEMI',     $1) if $$target =~ /\G (;;)   /gcx;
        return ('DLESS',     $1) if $$target =~ /\G (<<)   /gcx;
        return ('DGREAT',    $1) if $$target =~ /\G (>>)   /gcx;
        return ('LESSAND',   $1) if $$target =~ /\G (<&)   /gcx;
        return ('GREATAND',  $1) if $$target =~ /\G (>&)   /gcx;
        return ('LESSGREAT', $1) if $$target =~ /\G (<>)   /gcx;
        return ('DLESSDASH', $1) if $$target =~ /\G (<<-)  /gcx;
        return ('CLOBBER',   $1) if $$target =~ /\G (>\|)  /gcx;
        return ('CLOBBER',   $1) if $$target =~ /\G (>\|)  /gcx;

        if ($$target =~ /\G (for) /gcx) {
            $self->{prev_token} = 'For';
            return ('For', $1);
        }
        foreach my $w (@reserved_words) {
            if ($$target =~ /\G (\Q$w\E) /gcx) {
                return (uc(substr($w, 0, 1)) . substr($w, 1), $1);
            }
        }

        my $word = $self->_get_word();
        # if ($$target =~ /\G ([A-Za-z0-9\$\"'=]+) /gcx) {
        if ($word ne "") {
            # my $word = $1;
            if ($prev_token eq 'For') {
                return ('NAME', $word);
            }
            if ($$target =~ /\G \ * (\() /gcx) {
                $self->{inject} = ['(', $1];
                return ('NAME', $word);
            }


            return ('Lbrace', $word) if $word eq '{';
            return ('Rbrace', $word) if $word eq '}';
            return ('Bang',   $word) if $word eq '!';

            return ('ASSIGNMENT_WORD', $word) if ($word =~ /^[A-Za-z0-9]+=/);

            return ('WORD', $word);
            return ('UNKNOWN_WORD', $word);
        }

        return ($1, $1)       if $$target =~ /\G ([()|;&]) /gcx;

        return ('UNKNOWN', $1) if $$target =~ /\G (.) /gcx;

        $self->{current_line} = undef;
        return $self->_get_next_token();
    }
}

1;
