package ShellParser::Indent;

use strict;
use warnings;

use overload
	'+'     => \&plus_depth,
	'-'     => \&minus_depth,
	'++'    => \&incr_depth,
	'--'    => \&decr_depth,
	'""'    => \&as_string;

sub new {
	my ($class) = @_;
	my $self = {
#		separator => "\t",
		separator => "⇢\t",
		depth     => 0,
		condition => 0,
	};
	return bless($self, $class);
}

sub clone {
	my ($self) = @_;
	my $o = ShellParser::Indent->new();
	foreach my $k (keys %$self) {
		$o->{$k} = $self->{$k};
	}
	return $o;
}

sub plus_depth {
	my ($self, $value) = @_;
	my $o = $self->clone();
	$o->{depth} += $value;
	return $o;
}

sub minus_depth {
	my ($self, $value, $swap) = @_;
	my $o = $self->clone();
	$o->{depth} -= $value;
	$o->{depth} = -$o->{depth} if $swap;
	return $o;
}

sub incr_depth {
	my ($self) = @_;
	$self->{depth}++;
	return $self;
}

sub decr_depth {
	my ($self) = @_;
	$self->{depth}--;
	return $self;
}

sub as_string {
	my ($self) = @_;
	return (" " x $self->{depth}) if $self->{condition};
	return ($self->{separator} x $self->{depth});
}

1;
