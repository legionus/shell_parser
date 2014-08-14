package ShellParser::Token::Command;

use strict;
use warnings;

use base 'ShellParser::Token';

sub new {
    my ($class, $name, $args, $prefix) = @_;
    my $obj = {
        name   => $name,
        args   => [],
        prefix => [],
    };
    $obj->{args} = $args if $args and @{$args};
    $obj->{prefix} = $prefix if $prefix and @{$prefix};
    return bless($obj, $class);
}

1;
