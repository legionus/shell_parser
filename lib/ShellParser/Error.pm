package ShellParser::Error;

use strict;
use warnings;

use overload '""' => sub { $_[0]->as_string() };

sub new {
	my ($class, $msg) = @_;
	return bless({
		msg => $msg,
	}, $class);
}

sub as_string {
	my ($self) = @_;
	return $self->{msg};
}

1;
