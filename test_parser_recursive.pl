#!/usr/bin/env perl

use strict;
use warnings;
#use diagnostics;

use ShellParser;

package ShellParser::Token::Include;
use base 'ShellParser::Token::List';
sub p_args {
    my ($self) = @_;
    return $self->{filename};
}
package main;

sub include_files {
	my ($token, $name) = @_;

    if ($token->isa('ShellParser::Token::SimpleCommand') && $token->{name} && "$token->{name}" eq '.') {
        my $filename = $token->{args}->[0];
        if (open(my $fh, '<', $filename)) {
            my $p = ShellParser->new();
            my $result = $p->parse(sub { return scalar <$fh>; });
            warn "Error!11" if !defined($result);
            %{$token} = %{ShellParser::Token::Include->new($result)};
            close($fh);
            $token->{filename} = $filename;
            bless($token, 'ShellParser::Token::Include');
        } else {
            warn "$filename: $!";
        }
    }

    $token->traverse(\&include_files);
}

sub print_token {
	my ($sep, $depth, $token, $name) = @_;

	my $type = ref($token);
	$type =~ s/.*:://;

	$name //= "";
	$name = "$name: " if $name;

	print $sep x $depth . $name . $type . "(" . $token->p_args(). ")\n";
	$token->traverse(sub {
		print_token($sep, $depth + 1, @_);
	});
}

my $reader;
if (!$ARGV[0]) {
    die "Usage: $0 filename\n";
}

my $lineno = 0;
open(my $fh, '<', $ARGV[0]) or die $!;
$reader = sub {
    $lineno++;
    return scalar <$fh>;
};
my $p = ShellParser->new();
my $result = $p->parse($reader);
close($fh);

if (!$result) {
    my $err = $p->error;

    my $line = ($err->{line} // "(EOF)");
    chomp($line);
    $line =~ s/\t/ /;

    my $lineno_prefix = "$lineno: ";
    print $lineno_prefix . $line . "\n";
    print "-" x (length($lineno_prefix) + ($err->{position} // 1) - 1) . "^\n";
    print $err->{message} . "\n";
    exit(1);
} else {
    include_files($result);
	print_token(".   ", 0, $result);
}
