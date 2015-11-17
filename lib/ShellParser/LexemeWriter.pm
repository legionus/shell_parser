package ShellParser::LexemeWriter;

use strict;
use warnings;

sub new {
	my ($class) = @_;
	return bless({
		heredoc_buf => [],
	}, $class);
}

sub flush {
	my ($self) = @_;
	while (my $heredoc = shift(@{$self->{heredoc_buf}})) {
		foreach my $line (@{$heredoc->{lines}}) {
			print $line->raw_string() . "\n";
		}
		print $heredoc->{here_end}->dequote() . "\n";
	}
}

sub print {
	my ($self, $lexeme) = @_;
	if ($lexeme->isa("ShellParser::Lexeme::HereDoc")) {
		push(@{$self->{heredoc_buf}}, $lexeme);
	}
	print $lexeme->as_string();
	if ($lexeme->isa("ShellParser::Lexeme::NewLine")) {
		$self->flush();
	}
}

sub err {
	return;
}

1;
