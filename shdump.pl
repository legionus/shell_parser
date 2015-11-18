#!/usr/bin/env perl

use strict;
use warnings;

use IO::String;

use ShellParser;
use ShellParser::Lexeme::NewLine;
use ShellParser::Error;
use ShellParser::LexemeBuffer;
use ShellParser::LexemeWriter;
use ShellParser::Indent;

#use Carp qw(cluck);

sub dump_lexeme {
	my ($writer, $compactness, $prefix, $token) = @_;

	$writer->print($token);
	return $writer->err();
}

sub dump_word {
	my ($writer, $compactness, $prefix, $token) = @_;

	foreach my $i (0..$#{$token->{value}}) {
		#print "XXX: " . ref($token->{value}->[$i]) . "\n";
		my $err = dump_token($writer, $compactness, $prefix, $token->{value}->[$i]);
		return $err if defined($err);
	}

	return $writer->err();
}

sub dump_list {
	my ($writer, $compactness, $prefix, $token) = @_;

	foreach my $i (0..$#{$token->{body}}) {
		if (ref($token->{body}->[$i]) eq "ShellParser::Token::Comments") {
			if (@{$token->{body}->[$i]->{body}} > 0 && $compactness == 1) {
				$writer->print(ShellParser::Lexeme->new($prefix));
			}
		} elsif (ref($token->{body}->[$i]) eq "ShellParser::Token::AndOrList") {
			if ($compactness == 1) {
				$writer->print(ShellParser::Lexeme->new($prefix));
			} elsif ($i > 1 && $compactness >= 2) {
				$writer->print(ShellParser::Lexeme->new(" "));
			}
		} else {
			return ShellParser::Error->new("unexpected token $token->{body}->[$i] (".ref($token->{body}->[$i]).") inside of $token");
		}
		my $err = dump_token($writer, $compactness, $prefix, $token->{body}->[$i]);
		return $err if defined($err);
	}

	return $writer->err();
}

sub dump_comments {
	my ($writer, $compactness, $prefix, $token) = @_;

	if (@{$token->{body}} > 1) {
		$writer->print(ShellParser::Lexeme::NewLine->new());
		$writer->print(ShellParser::Lexeme->new($prefix));
	}

	foreach my $i (0..$#{$token->{body}}) {
		if ($compactness == 1 && $i > 0) {
			$writer->print(ShellParser::Lexeme->new($prefix));
		}
		$writer->print($token->{body}->[$i]);
		$writer->print(ShellParser::Lexeme::NewLine->new());
	}
	return $writer->err();
}

sub dump_commentedtoken {
	my ($writer, $compactness, $prefix, $token) = @_;
	my $err;

	$err = dump_token($writer, $compactness, $prefix, $token->{token});
	return $err if defined($err);

	if (@{$token->{comments}->{body}} > 0) {
		$writer->print(ShellParser::Lexeme->new(" "));
		$err = dump_token($writer, $compactness, $prefix, $token->{comments});
		return $err if defined($err);
	}

	#$writer->print(ShellParser::Lexeme::NewLine->new())
	return $writer->err();
}

sub dump_redirection {
	my ($writer, $compactness, $prefix, $token) = @_;
	my $err;

	$writer->print(ShellParser::Lexeme->new($token->{left}))
		if defined($token->{left});
	$writer->print(ShellParser::Lexeme->new($token->{redirection}));

	$err = dump_token($writer, $compactness, $prefix, $token->{filename});
	return $err if defined($err);
	return $writer->err();
}

sub dump_andorlist {
	my ($writer, $compactness, $prefix, $token) = @_;

	foreach my $elem (@{$token->{body}}) {
		if ($elem->isa("ShellParser::Lexeme::Operator")) {
			if ($compactness >= 2) {
				$writer->print(ShellParser::Lexeme->new(" "));
				$writer->print($elem);
				$writer->print(ShellParser::Lexeme->new(" "));
			} else {
				$writer->print(ShellParser::Lexeme->new(" "));
				$writer->print($elem);
				$writer->print(ShellParser::Lexeme::NewLine->new());
				$writer->print(ShellParser::Lexeme->new($prefix+1));
			}
		} else {
			if (ref($elem) eq "ShellParser::Token::Comments") {
				if (@{$elem->{body}} == 1) {
					$writer->print(ShellParser::Lexeme->new(" "));
				}
			}
			my $err = dump_token($writer, $compactness, $prefix, $elem);
			return $err if defined($err);
		}
	}

	if ($token->{sep} && $token->{sep} eq ";") {
		$token->{sep} = "";
	}

	if ($token->{sep} && $compactness < 2) {
		$writer->print(ShellParser::Lexeme->new(" "));
		$writer->print(ShellParser::Lexeme->new($token->{sep}));
	}

	if ($compactness >= 2) {
		$writer->print(ShellParser::Lexeme->new(";"))
			if !$token->{sep};
	} else {
		$writer->print(ShellParser::Lexeme::NewLine->new());
	}
	return $writer->err();
}

sub dump_pipeline {
	my ($writer, $compactness, $prefix, $token) = @_;

	if ($token->{banged}) {
		$writer->print(ShellParser::Lexeme->new("! "));
	}
	foreach my $i (0..$#{$token->{body}}) {
		my $err = dump_token($writer, $compactness, $prefix, $token->{body}->[$i]);
		return $err if defined($err);

		my $wanna_pipe = 0;
		for (my $j = $i + 1; $j <= $#{$token->{body}}; $j++) {
			if (ref($token->{body}->[$j]) eq "ShellParser::Token::SimpleCommand" ||
				ref($token->{body}->[$j]) eq "ShellParser::Token::CompoundCommand" ||
				ref($token->{body}->[$i]) eq "ShellParser::Token::CompoundCommand") {
				$wanna_pipe = 1;
				last;
			}
		}

		if (ref($token->{body}->[$i]) eq "ShellParser::Token::SimpleCommand" ||
			ref($token->{body}->[$i]) eq "ShellParser::Token::CompoundCommand" ||
			ref($token->{body}->[$i]) eq "ShellParser::Token::FuncDef") {
			if ($wanna_pipe) {
				$writer->print(ShellParser::Lexeme->new(" | "));
			}
		} elsif (ref($token->{body}->[$i]) eq "ShellParser::Token::Comments") {
			if (@{$token->{body}->[$i]->{body}} > 0 && $wanna_pipe) {
				$writer->print(ShellParser::Lexeme->new($prefix+1));
			}
		} else {
			return ShellParser::Error->new("unexpected token $token->{body}->[$i] inside of $token");
		}
	}
	return $writer->err();
}

sub dump_compoundcommand {
	my ($writer, $compactness, $prefix, $token) = @_;

	my $err = dump_token($writer, $compactness, $prefix, $token->{body});
	return $err if defined($err);

	foreach my $elem (@{$token->{redirect}}) {
		$writer->print(ShellParser::Lexeme->new(" "));
		$err = dump_token($writer, $compactness, $prefix, $elem);
		return $err if defined($err);
	}

	return $writer->err();
}

sub dump_while {
	my ($writer, $compactness, $prefix, $token) = @_;

	$writer->print(ShellParser::Lexeme->new("while"));

	my $buf;
	if ($compactness < 2) {
		$buf = ShellParser::LexemeBuffer->new(sub {
			my ($lexeme) = @_;
			if ($lexeme->isa("ShellParser::Lexeme::Comment") ||
				$lexeme->isa("ShellParser::Lexeme::NewLine")) {
				return ShellParser::Error->new("forbidden in this mode");
			}
			return;
		});

		my $err = dump_token($buf, 2, $prefix+1, $token->{condition});
		if (!defined($err)) {
			$writer->print(ShellParser::Lexeme->new(" "));
			$buf->copy_to($writer);

			$writer->print(ShellParser::Lexeme->new(" do"));
			$writer->print(ShellParser::Lexeme::NewLine->new());
		} else {
			$buf = ShellParser::LexemeBuffer->new();

			$err = dump_token($buf, $compactness, $prefix+1, $token->{condition});
			return $err if defined($err);

			$writer->print(ShellParser::Lexeme::NewLine->new());
			$buf->copy_to($writer);
			$writer->print(ShellParser::Lexeme->new("do"));
			$writer->print(ShellParser::Lexeme::NewLine->new());
		}
	} else {
		$buf = ShellParser::LexemeBuffer->new();
		my $err = dump_token($buf, $compactness, $prefix+1, $token->{condition});
		return $err if defined($err);

		$writer->print(ShellParser::Lexeme->new(" "));
		$buf->copy_to($writer);
		$writer->print(ShellParser::Lexeme->new(" do"));
		$writer->print(ShellParser::Lexeme::NewLine->new());
	}

	my $err = dump_token($writer, $compactness, $prefix+1, $token->{body});
	return $err if defined($err);

	if ($compactness < 2) {
		$writer->print(ShellParser::Lexeme->new($prefix));
	}
	$writer->print(ShellParser::Lexeme->new("done"));
	return $writer->err();
}

sub dump_wordlist {
	my ($writer, $compactness, $prefix, $token) = @_;

	foreach my $i (0..$#{$token->{body}}) {
		$writer->print(ShellParser::Lexeme->new(" ")) if $i > 0;
		my $err = dump_token($writer, $compactness, $prefix, $token->{body}->[$i]);
		return $err if defined($err);
	}
	return $writer->err();
}

sub dump_for {
	my ($writer, $compactness, $prefix, $token) = @_;
	my $err;

	$writer->print(ShellParser::Lexeme->new("for "));

	$err = dump_token($writer, $compactness, $prefix, $token->{variable});
	return $err if defined($err);

	my $semicolon = 1;
	if (defined($token->{wordlist})) {
		my $have_comment = 0;

		if (ref($token->{variable}) eq "ShellParser::Token::CommentedToken") {
			if (@{$token->{variable}->{comments}->{body}} > 0) {
				$have_comment = 1;
			}
		}

		$writer->print(ShellParser::Lexeme->new($have_comment ? $prefix+1 : " "));
		$writer->print(ShellParser::Lexeme->new("in "));

		$err = dump_token($writer, $compactness, $prefix+1, $token->{wordlist});
		return $err if defined($err);

		$semicolon = 0 if @{$token->{wordlist}->{comments}->{body}} > 0;
	}

	if ($semicolon) {
		$writer->print(ShellParser::Lexeme->new("; "))
	} else {
		$writer->print(ShellParser::Lexeme->new($prefix));
	}

	$writer->print(ShellParser::Lexeme->new("do"));
	$writer->print(ShellParser::Lexeme::NewLine->new());

	$err = dump_token($writer, $compactness, $prefix+1, $token->{body});
	return $err if defined($err);

	$writer->print(ShellParser::Lexeme->new($prefix));
	$writer->print(ShellParser::Lexeme->new("done"));
	return $writer->err();
}

sub dump_simplecommand {
	my ($writer, $compactness, $prefix, $token) = @_;
	my $err;

	foreach my $i (0..$#{$token->{prefix}}) {
		$writer->print(ShellParser::Lexeme->new(" "))
			if $i > 0;
		$err = dump_token($writer, $compactness, $prefix, $token->{prefix}->[$i]);
		return $err if defined($err);
	}

	return $writer->err() if !$token->{name};

	$writer->print(ShellParser::Lexeme->new(" "))
		if @{$token->{prefix}} > 0;

	$err = dump_token($writer, $compactness, $prefix+1, $token->{name});
	return $err if defined($err);

	foreach my $arg (@{$token->{args}}) {
		$writer->print(ShellParser::Lexeme->new(" "));
		$err = dump_token($writer, $compactness, $prefix+1, $arg);
		return $err if defined($err);
	}

	return $writer->err();
}

sub dump_ifcondition {
	my ($writer, $compactness, $prefix, $token) = @_;

	my $buf;
	if ($compactness < 2) {
		$buf = ShellParser::LexemeBuffer->new(sub {
			my ($lexeme) = @_;
			if ($lexeme->isa("ShellParser::Lexeme::Comment") ||
				$lexeme->isa("ShellParser::Lexeme::NewLine")) {
				return ShellParser::Error->new("forbidden in this mode");
			}
			return;
		});

		my $err = dump_token($buf, 2, $prefix+1, $token);
		if (!defined($err)) {
			$writer->print(ShellParser::Lexeme->new(" "));
			$buf->copy_to($writer);

			$writer->print(ShellParser::Lexeme->new(" then"));
			$writer->print(ShellParser::Lexeme::NewLine->new());
		} else {
			$buf = ShellParser::LexemeBuffer->new();

			$err = dump_token($buf, $compactness, $prefix+1, $token);
			return $err if defined($err);

			$writer->print(ShellParser::Lexeme::NewLine->new());
			$buf->copy_to($writer);
			$writer->print(ShellParser::Lexeme->new("then"));
			$writer->print(ShellParser::Lexeme::NewLine->new());
		}
	} else {
		$buf = ShellParser::LexemeBuffer->new();
		my $err = dump_token($buf, $compactness, $prefix+1, $token);
		return $err if defined($err);

		$writer->print(ShellParser::Lexeme->new(" "));
		$buf->copy_to($writer);
		$writer->print(ShellParser::Lexeme->new(" then"));
		$writer->print(ShellParser::Lexeme::NewLine->new());
	}

	return;
}

sub dump_if {
	my ($writer, $compactness, $prefix, $token) = @_;
	my $err;
	my $conds = 0;

	foreach my $subtoken (@{$token->{body}}) {
		if (defined($subtoken->{condition})) {
			$writer->print(ShellParser::Lexeme->new($conds ? "elif" : "if"));
			dump_ifcondition($writer, $compactness, $prefix, $subtoken->{condition});
			$conds++;
		} else {
			$writer->print(ShellParser::Lexeme->new($prefix));
			$writer->print(ShellParser::Lexeme->new("else"));
			$writer->print(ShellParser::Lexeme::NewLine->new());
		}

		$err = dump_token($writer, $compactness, $prefix+1, $subtoken->{body});
		return $err if defined($err);
	}

	$writer->print(ShellParser::Lexeme->new($prefix));
	$writer->print(ShellParser::Lexeme->new("fi"));
	return $writer->err();
}

sub dump_function {
	my ($writer, $compactness, $prefix, $token) = @_;

	$writer->print($token->{name}->{token});
	$writer->print(ShellParser::Lexeme->new("()"));
	$writer->print(ShellParser::Lexeme->new(" "));

	my $err;

	$err = dump_token($writer, $compactness, $prefix, $token->{name}->{comments});
	return $err if defined($err);

	$err = dump_token($writer, $compactness, $prefix, $token->{body});
	return $err if defined($err);

	return $writer->err()
		if !$token->{redirect};

	foreach my $i (0..$#{$token->{redirect}}) {
		$writer->print(ShellParser::Lexeme->new(" "));
		$err = dump_token($writer, $compactness, $prefix, $token->{redirect}->[$i]);
		return $err if defined($err);
	}

	return $writer->err();
}

sub dump_bracegroup {
	my ($writer, $compactness, $prefix, $token) = @_;
	$writer->print(ShellParser::Lexeme->new("{"));
	$writer->print(
		$compactness < 2
			? ShellParser::Lexeme::NewLine->new()
			: ShellParser::Lexeme->new(" ")
	);

	my $err = dump_token($writer, $compactness, $prefix+1, $token->{body});
	return $err if defined($err);

	$writer->print(ShellParser::Lexeme->new($prefix)) if $compactness == 1;
	$writer->print(ShellParser::Lexeme->new(" "))     if $compactness == 2;
	$writer->print(ShellParser::Lexeme->new("}"));

	return $writer->err();
}

sub dump_caseitemlist {
	my ($writer, $compactness, $prefix, $token) = @_;
	my $err;

	foreach my $i (0..$#{$token->{body}}) {
		$err = dump_token($writer, $compactness, $prefix, $token->{body}->[$i]);
		return $err if defined($err);
	}

	return $writer->err();
}

sub dump_caseitem {
	my ($writer, $compactness, $prefix, $token) = @_;
	my $err;

	$writer->print(ShellParser::Lexeme->new($prefix));
	$writer->print(ShellParser::Lexeme->new("("));

	foreach my $i (0..$#{$token->{pattern}}) {
		$writer->print(ShellParser::Lexeme->new("|"))
			if $i > 0;
		$err = dump_token($writer, $compactness, $prefix+1, $token->{pattern}->[$i]);
		return $err if defined($err);
	}

	$writer->print(ShellParser::Lexeme->new(")"));
	$writer->print(ShellParser::Lexeme::NewLine->new());

	$err = dump_token($writer, $compactness, $prefix+1, $token->{body});
	return $err if defined($err);

	if (defined($token->{dsemi})) {
		$writer->print(ShellParser::Lexeme->new($prefix+1));
		$err = dump_token($writer, $compactness, $prefix+1, $token->{dsemi});
		return $err if defined($err);

		$writer->print(ShellParser::Lexeme::NewLine->new());
	}

	return $writer->err();
}

sub dump_case {
	my ($writer, $compactness, $prefix, $token) = @_;
	my $err;

	$writer->print(ShellParser::Lexeme->new("case "));

	$err = dump_token($writer, $compactness, $prefix+1, $token->{word});
	return $err if defined($err);

	$writer->print(ShellParser::Lexeme->new(" in"));
	$writer->print(ShellParser::Lexeme::NewLine->new());

	$err = dump_token($writer, $compactness, $prefix+1, $token->{items});
	return $err if defined($err);

	$writer->print(ShellParser::Lexeme->new($prefix));
	$writer->print(ShellParser::Lexeme->new("esac"));

	return $writer->err();
}

sub dump_commandsubstitution {
	my ($writer, $compactness, $prefix, $token) = @_;
	my $err;

	$writer->print(ShellParser::Lexeme->new("\"\$\("));

	foreach my $i (0..$#{$token->{tokens}}) {
		$err = dump_token($writer, $compactness, $prefix+1, $token->{tokens}->[$i][1]);
		return $err if defined($err);
	}

	$writer->print(ShellParser::Lexeme->new("\)\""));
	return $writer->err();
}

sub dump_subshell {
	my ($writer, $compactness, $prefix, $token) = @_;

	$writer->print(ShellParser::Lexeme->new("("));

	my $buf;
		$buf = ShellParser::LexemeBuffer->new(sub {
			my ($lexeme) = @_;
			if ($lexeme->isa("ShellParser::Lexeme::Comment") ||
				$lexeme->isa("ShellParser::Lexeme::NewLine")) {
				return ShellParser::Error->new("forbidden in this mode");
			}
			return;
		});

		my $err = dump_token($buf, 2, $prefix+1, $token->{body});
		if (!defined($err)) {
			$buf->copy_to($writer);
		} else {
			$buf = ShellParser::LexemeBuffer->new();

			$err = dump_token($buf, $compactness, $prefix+1, $token->{body});
			return $err if defined($err);

			$writer->print(ShellParser::Lexeme::NewLine->new());
			$buf->copy_to($writer);
		}

	$writer->print(ShellParser::Lexeme->new($prefix)) if $compactness == 1;
	$writer->print(ShellParser::Lexeme->new(")"));

	return;
}

my $dumper = {
	Lexeme              => \&dump_lexeme,
	List                => \&dump_list,
	Word                => \&dump_word,
	WordList            => \&dump_wordlist,
	Comments            => \&dump_comments,
	CommentedToken      => \&dump_commentedtoken,
	AndOrList           => \&dump_andorlist,
	Pipeline            => \&dump_pipeline,
	SimpleCommand       => \&dump_simplecommand,
	CompoundCommand     => \&dump_compoundcommand,
	While               => \&dump_while,
	For                 => \&dump_for,
	If                  => \&dump_if,
	FuncDef             => \&dump_function,
	BraceGroup          => \&dump_bracegroup,
	Redirection         => \&dump_redirection,
	Case                => \&dump_case,
	CaseItem            => \&dump_caseitem,
	CaseItemList        => \&dump_caseitemlist,
	CommandSubstitution => \&dump_commandsubstitution,
	SubShell            => \&dump_subshell,
};

sub dump_token {
	my ($writer, $compactness, $prefix, $token) = @_;

	# $prefix = "\n" . $prefix . "[" . $token . "]";
	# print "[$prefix] " . $token . "\n";

	my $type = ref($token);
	$type =~ s/.*:://;

#	print "$type\n";

	if ($token->isa("ShellParser::Lexeme") && !$dumper->{$type}) {
		$type = "Lexeme";
	}

	my $func = $dumper->{$type} || 0;
	return $func->($writer, $compactness, $prefix, $token) if $func;

	use Data::Dumper;
	print Dumper($token);

	return ShellParser::Error->new("unexpected token $token");
}

sub parse_subshell {
	my ($token) = @_;
	my $type = ref($token);

	if ($type =~ /^.*::CommandSubstitution$/) {
		my $p = ShellParser->new();

		my $subshell = join('', map { $_->[1]->raw_string() } @{$token->{tokens}});
		my $io = IO::String->new($subshell);

		$token->{body} = $p->parse(sub { return scalar <$io>; });
		return $token->{body}->traverse(\&parse_subshell);
	}

	return $token->traverse(\&parse_subshell);
}

sub parse_file {
	my ($filename) = @_;

	my $p = ShellParser->new();

	open(my $fh, '<', $filename) or die $!;

	my $lineno = 0;
	my $result = $p->parse(sub {
		$lineno++;
		return scalar <$fh>;
	});

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
	}

	parse_subshell($result);

	return $result;
}

my $result = parse_file($ARGV[0]);
my $writer = ShellParser::LexemeWriter->new();
my $err = dump_token($writer, 1, ShellParser::Indent->new(), $result);
if ($err) {
	print "ERROR: $err\n";
}
