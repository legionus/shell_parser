package ShellParser::Token::FuncDef;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $name, $body, $redirect) = @_;
    return bless({
        name     => $name,
        body     => $body,
        redirect => $redirect,
    }, $class);
}

sub print {
    my ($self, $sep, $depth) = @_;
    print $sep x $depth . "FuncDef(name=$self->{name})\n";
    print $sep x $depth . $sep . "FuncDef::body()\n";
    $self->{body}->print($sep, $depth + 2);
    if ($self->{redirect}) {
    	print $sep x $depth . $sep . "FuncDef::redirect()\n";
    	foreach my $redirect (@{$self->{redirect}}) {
		    $redirect->print($sep, $depth + 2);
    	}
    }
}

1;
