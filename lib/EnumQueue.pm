package EnumQueue;
use strict;
use warnings;

use Carp qw( confess );

=head1 NAME

EnumQueue - A queue based on a mutable subset of a given ordered set.

=head1 SYNOPSIS

    use EnumQueue;
    my $queue =
      EnumQueue->new( full_ordered_set => [qw( first second third )] );
    $queue->offer('third');     # returns 1
    $queue->offer('third');     # returns 0
    $queue->offer('second');    # returns 1
    $queue->poll();             # returns 'second'
    $queue->poll();             # returns 'third'
    $queue->poll();             # returns undef

=head1 CONSTRUCTORS

=head2 new

Constructs a new EnumQueue.

Takes an arraylist of strings in the B<full_ordered_set> argument.

Dies if the full ordered set argument contains repeated elements.

=cut

sub new {
    my ( $class, %args ) = @_;
    my $full_ordered_set = delete $args{full_ordered_set};
    !%args
      or confess "unrecognized arguments";

    my $i = 0;
    my %order = map { $_ => $i++ } @{ $full_ordered_set };
    ( scalar keys %order == scalar @{$full_ordered_set} )
      or confess 'repeated element in full ordered set';

    my $self = bless {}, $class;

    $self->{order} = \%order;
    $self->{elements} = [];

    return $self;
}

=head1 INSTANCE METHODS

=head2 offer

Enqueue a an element.

Returns C<1> if the element is added to the queue, or
C<0> if the element is already present in the queue.

Dies if the element is not recognized.

=cut

sub offer {
    my $self    = shift;
    my $element = shift;

    my $index = $self->{order}{$element} // confess "unrecognized element";

    return 0 if defined $self->{elements}[$index];

    $self->{elements}[$index] = $element;
    return 1;
}

=head2 poll

Return the first element in the queue and remove it.

If the queue is empty, C<undef> is returned.

=cut

sub poll {
    my $self = shift;

    my $index = $self->_peek_index();
    return undef if !defined $index;

    my $element = $self->{elements}[$index];
    undef $self->{elements}[$index];
    return $element;
}

=head2 poll

Return the first element in the queue without removing it.

If the queue is empty, C<undef> is returned.

=cut

sub peek {
    my $self = shift;

    my $index = $self->_peek_index();
    return undef if !defined $index;

    return $self->{elements}[$index];
}

sub _peek_index {
    my $self = shift;

    for my $index ( 0 .. $#{ $self->{elements} } ) {
        return $index if defined $self->{elements}[$index];
    }
    return undef;
}

1;
