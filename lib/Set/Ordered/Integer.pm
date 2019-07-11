package Set::Ordered::Integer;
use strict;
use warnings;

use Carp qw( confess );

=head1 NAME

Set::Ordered::Integer - A mutable ordered set backed by an integer.

=head1 SYNOPSIS

    my $set = Set::Ordered::Integer->new( elements => [ 3, 5, 7 ] );
    $set->insert(4);    # returns 1, for true
    $set->pop_min();    # returns 3, for the value 3
    $set->pop_min();    # returns 4, for the value 4

=head1 DESCRIPTION

This ordered set implementation is geared towards use cases where you care about
resource efficiency and the elements are small integers.

=head2 Implementation details

Elements are represented by positions in the backing integer.
If a bit is one, the element is present in the set, otherwise it's not.

Operations involve lots of bit twiddling.

=head1 CONSTRUCTORS

=head2 new

Construct a new instance.

    my $set = Set::Ordered::Integer->new( elements => [ 3, 5, 7 ] );

Takes one argument:

=over

=item elements

An arrayref of initial elements.
If you provide it, new() will call insert() for each element.
Default is an empty arrayref.

=cut


sub new {
    my ( $class, %args ) = shift;
    my $elements = delete $args{elements};
    !%args
      or confess 'unexpected arguments';

    $elements //= [];

    my $value = 0;

    my $self = bless \$value, $class;

    $self->insert($_) for @{$elements};

    return $self;
}

=head2 insert

Insert an element into the set, unless already present.

    my $set = Set::Ordered::Integer->new( elements => [ 3, 5, 7 ] );
    my $value = $set->insert(3);    # returns 0
    my $value = $set->insert(6);    # returns 1

Returns C<1> if the value was inserted, or C<0> if the value was already present.

=cut

sub insert {
    my $self = shift;
    my $value  = shift;

    my $bit = 1 << $value;

    my $rv = ( ( $$self & $bit ) == 0 );

    $$self |= $bit;

    return $rv;
}

=head2 pop_min

Removes and returns the smallest element, or C<undef> if the set is empty.

    my $set = Set::Ordered::Integer->new( elements => [ 3, 5, 7 ] );
    my $value = $set->pop_min();    # returns 3

=cut

sub pop_min {
    my $self = shift;

    # Counts number of zeroes less significant than the least significant one.
    #
    # Algorithm adapted from https://graphics.stanford.edu/~seander/bithacks.html#ZerosOnRightParallel

    return undef if $$self == 0;

    my $count;
    $$self = ( $$self ^ ( $$self - 1 ) ) >> 1;
    for ( $count = 0 ; $$self ; $count++ ) {
        $$self >>= 1;
    }

    $$self &= ~( 1 << $count );

    return $count;
}

1;
