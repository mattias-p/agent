package Heap::Binary;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $cmp   = shift;

    my $self = bless {}, $class;

    $self->{cmp}   = $cmp;
    $self->{items} = [undef];

    return $self;
}

sub find_min {
    my $self = shift;
    return $self->{items}[1];
}

sub insert {
    my $self  = shift;
    my $value = shift;

    push @{$self->{items}}, $value;
    $self->_sift( $#{$self->{items}} );

    return;
}

sub extract_min {
    my $self = shift;

    my $value = $self->{items}[1];

    my $i = $self->_sink(1);

    if ( $i < $#{$self->{items}} ) {
        $self->{items}[$i] = pop @{$self->{items}};
        $self->_sift($i);
    }
    elsif ( $i == $#{$self->{items}} ) {
        pop @{$self->{items}};
    }

    return $value;
}

sub _sift {
    my $self = shift;
    my $i    = shift;

    my $items = $self->{items};

    while ( $i > 1 )  {
        my $p = $i / 2;
        if ( $self->{cmp}( $items->[$i], $items->[$p] ) < 0 ) {
            my $tmp = $items->[$p];
            $items->[$p] = $items->[$i];
            $items->[$i] = $tmp;

            $i = $p;
        }
        else {
            last;
        }
    }

    return;
}

sub _sink {
    my $self = shift;

    my $items = $self->{items};

    my $i = 1;
    my $j = $i * 2;
    my $k = $i * 2 + 1;

    while ( $k <= $#{$items} ) {
        if ( $self->{cmp}( $items->[$j], $items->[$k] ) < 0 ) {
            $items->[$i] = $items->[$j];
            $i = $j;
        }
        else {
            $items->[$i] = $items->[$k];
            $i = $k;
        }

        $j = $i * 2;
        $k = $i * 2 + 1;
    }

    if ( $j <= $#{$items} ) {
        $items->[$i] = $items->[$j];
        $i = $j;
    }

    return $i;
}

1;
