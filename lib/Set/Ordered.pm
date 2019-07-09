package Set::Ordered;
use strict;
use warnings;

use Carp qw( confess );

sub new {
    my ( $class, %args ) = @_;
    my $cmp      = delete $args{cmp};
    my $elements = delete $args{elements};
    !%args or confess 'unrecognized arguments';

    $cmp //= sub { $_[0] <=> $_[1] };
    $elements //= [];

    my $self = bless {}, $class;

    $self->{cmp}      = $cmp;
    $self->{elements} = $elements;

    return $self;
}

sub peek_min {
    my $self = shift;

    return $self->{elements}[0];
}

sub insert {
    my $self      = shift;
    my $timestamp = shift;

    my ($le, $ge) = $self->binary_search($timestamp);

    return 0 if $le == $ge;

    splice @{ $self->{elements} }, $ge, 0, $timestamp;

    return 1;
}

sub remove_le {
    my $self      = shift;
    my $timestamp = shift;

    my ($le, undef) = $self->binary_search($timestamp);

    splice @{ $self->{elements} }, 0, $le + 1;

    return $le + 1;
}

=head2 binary_search

    my ( $le, $ge );

    my $s0 = Set::Ordered->new( elements => [] );
    ( $le, $ge ) = $s0->binary_search(3);    # returns -1, 0

    my $s1 = Set::Ordered->new( elements => [3] );
    ( $le, $ge ) = $s1->binary_search(2);    # returns -1, 0
    ( $le, $ge ) = $s1->binary_search(3);    # returns  0, 0
    ( $le, $ge ) = $s1->binary_search(4);    # returns  0, 1

    my $s3 = Set::Ordered->new( elements => [ 1, 3, 5 ] );
    ( $le, $ge ) = $s3->binary_search(0);    # returns -1, 0
    ( $le, $ge ) = $s3->binary_search(1);    # returns  0, 0
    ( $le, $ge ) = $s3->binary_search(2);    # returns  0, 1
    ( $le, $ge ) = $s3->binary_search(3);    # returns  1, 1
    ( $le, $ge ) = $s3->binary_search(4);    # returns  1, 2
    ( $le, $ge ) = $s3->binary_search(5);    # returns  2, 2
    ( $le, $ge ) = $s3->binary_search(6);    # returns  2, 3

=cut

sub binary_search {
    my $self      = shift;
    my $timestamp = shift;

    my $left  = 0;
    my $right = $#{ $self->{elements} };

    while ( $left <= $right ) {
        my $middle = ( $left + $right ) / 2;
        my $cmp    = $self->{cmp}( $self->{elements}[$middle], $timestamp );
        if ( $cmp < 0 ) {
            $left = $middle + 1;
        }
        elsif ( $cmp > 0 ) {
            $right = $middle - 1;
        }
        else {
            return $middle, $middle;
        }
    }

    return $right, $left;
}

1;
