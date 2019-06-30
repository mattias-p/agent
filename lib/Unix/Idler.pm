package Unix::Idler;
use strict;
use warnings;

use POSIX qw( pause );

sub new {
    my $class = shift;

    my $self = bless {}, $class;

    return $self;
}

sub idle {
    pause;
    return;
}

1;
