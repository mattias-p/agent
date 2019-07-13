package Set::Ordered::BitVector;
use strict;
use warnings;

use Carp qw( confess );

=head1 NAME

Set::Ordered::BitVector - A mutable ordered set backed by a bit vector.

=head1 SYNOPSIS

    my $set = Set::Ordered::BitVector->new();
    $set->insert(5);    # returns 1, for true
    $set->insert(3);    # returns 1, for true
    $set->pop_min();    # returns 3, for the value 3

=head1 DESCRIPTION

This ordered set implementation is geared towards use cases where you care about
resource efficiency and the elements are small integers.

=head2 Implementation details

Each element is represented by a bit in the backing bit vector.
If a bit is one, the element is present in the set, otherwise it's not.

Operations involve lots of bit twiddling.

=head1 CONSTRUCTORS

=head2 new

Construct a new instance.

    my $set = Set::Ordered::BitVector->new();

Takes one argument:

=over

=item elements

An arrayref of initial elements.
If you provide it, new() will call insert() for each element.
Default is an empty arrayref.

=cut

sub new {
    my ( $class, %args ) = shift;
    !%args
      or confess 'unexpected arguments';

    my $value = '';

    my $self = bless \$value, $class;

    return $self;
}

=head2 insert

Insert an element into the set, unless already present.

    my $set = Set::Ordered::BitVector->new();
    my $value = $set->insert(3);    # returns 1
    my $value = $set->insert(3);    # returns 0

Returns C<1> if the value was inserted, or C<0> if the value was already present.

=cut

sub insert {
    my $self = shift;
    my $value  = shift;

    my $rv = !vec( $$self, $value, 1 );

    vec( $$self, $value, 1 ) = 1;

    return $rv;
}

=head2 pop_min

Removes and returns the smallest element, or C<undef> if the set is empty.

    my $set = Set::Ordered::BitVector->new();
    my $value = $set->insert(3);    # returns 1
    my $value = $set->insert(5);    # returns 1
    my $value = $set->pop_min();    # returns 3

=cut

sub pop_min {
    my $self = shift;

    # Counts number of zeroes less significant than the least significant one.
    #
    # Algorithm adapted from https://graphics.stanford.edu/~seander/bithacks.html#ZerosOnRightParallel

    my $bits = 8 * length $$self;

    for my $i ( 0..$bits ) {
        if ( vec( $$self, $i, 1 ) ) {
            vec( $$self, $i, 1 ) = 0;
            return $i
        }
    }

    return undef;
}

1;
