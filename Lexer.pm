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
        downgrade_assignment_word => 0,
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
        $value .= "\n" . $self->_get_rest_qq_string();
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
        if ($c != /[^\s<>()|;&]/) {
            $value .= $self->_get_word();
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
        print "word: $value\n";
    }

    $self->{current_line} = $self->{reader}->('token', '$(');
    die "Unexpected end of input" if !defined($self->{current_line});
    $value .= "\n" . $self->_get_rest_db_string();
    return $value;
}

sub _get_word {
    my ($self) = @_;
    my $target = \$self->{current_line};

    my $value = "";

    while ($$target =~ /\G ([^\s<>()|;&]) /gcx) {
        my $c = $1;
        $value .= $c;
        if ($c eq "'") {
            $value .= $self->_get_rest_q_string();
        } elsif ($c eq '"') {
            $value .= $self->_get_rest_qq_string();
        } elsif ($c eq '`') {
            $value .= $self->_get_rest_qx_string();
        } elsif ($c eq '$') {
            if ($$target =~ /\G (\(\() /gcx) {
                $value .= $1 . $self->_get_rest_dbb_string();
            } elsif ($$target =~ /\G (\() /gcx) {
                $value .= $1 . $self->_get_rest_db_string();
            }

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
    print "target: $$target\n";
    TOKEN: {
        if ($$target =~ /\G \n /gcx) {
            $self->{downgrade_assignment_word} = 0;
            return ('NEWLINE', '');
        }
        if ($$target =~ /\G (\#.*) /gcx) {
            $self->{downgrade_assignment_word} = 0;
            return ('NEWLINE', $1);
        }
        redo if $$target =~ /\G \s+ /gcx;

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

            if (!$self->{downgrade_assignment_word}) {
                return ('ASSIGNMENT_WORD', $word) if ($word =~ /^[A-Za-z0-9]+=/);
            }

            $self->{downgrade_assignment_word} = 1;

            return ('WORD', $word);
            return ('UNKNOWN_WORD', $word);
        }

        $self->{downgrade_assignment_word} = 0;
        return ($1, $1)       if $$target =~ /\G ([<>()|;&]) /gcx;

        return ('UNKNOWN', $1) if $$target =~ /\G (.) /gcx;

        $self->{current_line} = undef;
        return $self->_get_next_token();
    }
}

1;
