package Allocator;
use strict;
use warnings;

sub new {
    my $class = shift;
    
    my $self = bless {}, $class;

    $self->{counter} = 0;

    return $self;
}

sub claim {
    my $self = shift;

    if ( rand() < 0.75 ) {
        $self->{counter} += 1;
        return $self->{counter};
    }
    else {
        return;
    }
}

sub release {
    my $self = shift;
    my $id   = shift;

    return;
}

1;
