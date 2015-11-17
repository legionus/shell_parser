package ShellParser::LexemeBuffer;

use strict;
use warnings;

sub new {
	my ($class, $check) = @_;
	return bless({
		buf => [],
		check => $check // sub { return },
		err => undef,
	}, $class);
}

sub print {
	my ($self, $lexeme) = @_;

	return if defined($self->{err});

	my $err = $self->{check}->($lexeme);
	if (defined($err)) {
		$self->{err} = $err;
		return;
	}

	push(@{$self->{buf}}, $lexeme);
}

sub copy_to {
	my ($self, $writer) = @_;
	foreach my $x (@{$self->{buf}}) {
		$writer->print($x);
	}
}

sub err {
	my ($self) = @_;
	return $self->{err};
}

1;
