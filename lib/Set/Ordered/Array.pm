package Set::Ordered::Array;
use strict;
use warnings;

use Carp qw( confess );

=head1 NAME

Set::Ordered::Array - A mutable ordered set backed by an array.

=head1 SYNOPSIS

    my $set = Set::Ordered::Array->new( elements => [ 1, 3, 5 ] );
    $set->insert(4);       # returns 1, for true
    $set->remove_le(3);    # returns 2, for 2 elements
    $set->peek_min();      # returns 4, for the value 4

=head1 DESCRIPTION

This ordered set implementation is geared towards use cases where you are most
likely to insert or remove either minimum or maximum elements.

=head2 Implementation details

Updates are made with the splice() built-in.
Binary search is used for finding elements and positions within the array.

=head1 CONSTRUCTORS

=head2 new

Construct a new instance.

    my $set = Set::Ordered::Array->new(
        elements => [ "Alpha", "Charlie", "Echo" ],
        cmp      => sub        { $_[0] cmp $_[1] },
    );

Takes two arguments:

=over

=item elements

An arrayref of initial elements.
Default is an empty arrayref.

=item cmp

A coderef that compares tho elements.
Default is C<sub { $_[0] E<lt>=E<gt> $_[1] }>.

=back

=cut

sub new {
    my ( $class, %args ) = @_;
    my $cmp      = delete $args{cmp};
    my $elements = delete $args{elements};
    !%args
      or confess 'unrecognized arguments';

    $cmp //= sub { $_[0] <=> $_[1] };
    $elements //= [];

    $elements = [ sort { $cmp->( $a, $b ) } @{$elements} ];

    my $self = bless {}, $class;

    $self->{cmp}      = $cmp;
    $self->{elements} = $elements;

    return $self;
}

=head1 INSTANCE METHODS

=head2 peek_min

Get the smallest element in the set, or C<undef> is the set is empty.

    my $set = Set::Ordered::Array->new( elements => [ 1, 3, 5 ] );
    my $value = $set->peek_min();    # returns 1

=cut

sub peek_min {
    my $self = shift;

    return $self->{elements}[0];
}

=head2 insert

Insert an element into the set, unless already present.

    my $set = Set::Ordered::Array->new( elements => [ 1, 3, 5 ] );
    my $value = $set->insert(3);    # returns 0
    my $value = $set->insert(6);    # returns 1

Returns C<1> if the value was inserted, or C<0> if the value was already present.

=cut

sub insert {
    my $self      = shift;
    my $timestamp = shift;

    my ($le, $ge) = $self->_search($timestamp);

    return 0 if $le == $ge;

    splice @{ $self->{elements} }, $ge, 0, $timestamp;

    return 1;
}

=head2 remove_le

Removes all elements less than or equal to a given value.

    my $set = Set::Ordered::Array->new( elements => [ 1, 3, 5 ] );
    my $value = $set->remove_le(3);    # returns 2

Returns the number of elements removed.

=cut

sub remove_le {
    my $self      = shift;
    my $timestamp = shift;

    my ($le, undef) = $self->_search($timestamp);

    splice @{ $self->{elements} }, 0, $le + 1;

    return $le + 1;
}

=head2 _search

Find the smallest range that includes a given value.

The bounds of the range are selected from the elements of the set, with the
addition of negative and positive infinity.

The range is inclusive.

The returned values are not the bounds themselves but rather the indices of
their respective elements.

In case the bounds are not proper elements, but rather negative or positive
infinity, -1 or the length of the array, respectively.

Negative and positive infinity are represented by C<-1> and the number of
elements, respectively.

    my ( $le, $ge );

    my $s0 = Set::Ordered->new( elements => [] );
    ( $le, $ge ) = $s0->_search(3);    # returns -1, 0

    my $s1 = Set::Ordered->new( elements => [3] );
    ( $le, $ge ) = $s1->_search(2);    # returns -1, 0
    ( $le, $ge ) = $s1->_search(3);    # returns  0, 0
    ( $le, $ge ) = $s1->_search(4);    # returns  0, 1

    my $s3 = Set::Ordered->new( elements => [ 1, 3, 5 ] );
    ( $le, $ge ) = $s3->_search(0);    # returns -1, 0
    ( $le, $ge ) = $s3->_search(1);    # returns  0, 0
    ( $le, $ge ) = $s3->_search(2);    # returns  0, 1
    ( $le, $ge ) = $s3->_search(3);    # returns  1, 1
    ( $le, $ge ) = $s3->_search(4);    # returns  1, 2
    ( $le, $ge ) = $s3->_search(5);    # returns  2, 2
    ( $le, $ge ) = $s3->_search(6);    # returns  2, 3

=cut

sub _search {
    my $self      = shift;
    my $timestamp = shift;

    my $left  = 0;
    my $right = $#{ $self->{elements} };

    while ( $left <= $right ) {
        my $middle = ( $left + $right ) / 2;
        my $relation = $self->{cmp}( $self->{elements}[$middle], $timestamp );
        if ( $relation < 0 ) {
            $left = $middle + 1;
        }
        elsif ( $relation > 0 ) {
            $right = $middle - 1;
        }
        else {
            return $middle, $middle;
        }
    }

    return $right, $left;
}

1;
