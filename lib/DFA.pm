package DFA;
use strict;
use warnings;

=head1 NAME

DFA - A representation of deterministic finite automata.

=head1 SYNOPSIS

    use DFA;
    my $turnstile = DFA->new(
        initial_state => 'locked',
        final_states => [],
        transitions => {
            'locked' => {
                'push' => 'locked',
                'coin' => 'unlocked',
            },
            'unlocked' => {
                'push' => 'locked',
                'coin' => 'unlocked',
            },
        },
    );
    print $turnstile->state, "\n";
    $turnstile->process( 'push' );
    print $turnstile->state, "\n";
    $turnstile->process( 'push' );
    print $turnstile->state, "\n";
    $turnstile->process( 'coin' );
    print $turnstile->state, "\n";
    $turnstile->process( 'push' );
    print $turnstile->state, "\n";

=head1 DESCRIPTION

A very simple L<DFA|https://en.wikipedia.org/wiki/Deterministic_finite_automaton>.
It closely matches the formal definition.

Both input symbols and states are represented by strings.

The ranges of valid state and input names is slightly restricted in order to
guarantee readable error messages.

Technically, state and input names live in separate namespaces, but your life
will most likely be simpler if you avoid ambiguous state and input names.

=head2 Not a full-featured finite state machine

Some FSMs (e.g. Moore and Mealy machines) extend deterministic finite automata
with an output function.
This module does NOT support that out of the box.

Some FSMs extend deterministic finite automata with entry actions, exit actions,
input actions and/or transition actions.
This module does NOT support that out of the box.

=cut

use Carp qw( confess );
use DFA::Util qw( is_transition_mapping is_name is_arrayref );
use List::Util qw( all );

=head1 CONSTRUCTORS

=head2 new

Construct a new DFA instance.

    use DFA;
    my $is_even = DFA->new(
        transitions => {
            'even' => {
                'add_one' => 'odd',
            },
            'odd' => {
                'add_one' => 'even',
            },
        },
        initial_state => 'even',
        final_states  => ['even'],
    );

Throws an exception if the arguments would not result in a valid DFA.
The requirements are:

=over

=item
The transitions argument is a valid transition mapping.
=item
The initial_state argument matches a from-state in the transitions argument.
=item
The final_states argument is an arrayref whose elements match from-states in the
transitions argument.
=item
A transition mapping is a top-level hashref that maps from-state strings to
second-level hashrefs that in turn map input symbol strings to to-state strings.
=item
The same set of input symbols must be uses for each from-state in the
transitions argument.
=item
Each to-state must also exist as a from-state in the transitions argument.
=item
Each from-state must be reachable from the initial-state.

=back

=cut

sub new {
    my ( $class, %args ) = @_;
    my $transitions   = delete $args{transitions};
    my $initial_state = delete $args{initial_state};
    my $final_states  = delete $args{final_states};
    !%args or confess 'unexpected args';

    is_transition_mapping($transitions)
      or confess 'transitions argument must be a valid transition mapping';

    my %all_from_states =
      map { $_ => 1 }
      keys %{$transitions};
    my %all_inputs =
      map { $_ => 1 }
      map { keys %{$_} } values %{$transitions};
    my %all_to_states =
      map { $_ => 1 }
      map { values %{$_} } values %{$transitions};

    all { exists $transitions->{$_} } keys %all_to_states
      or confess "one or more to-state is not defined as a from-state";

    for my $from_state (keys %all_from_states) {
        my @states = grep { !exists $transitions->{$from_state}{$_} } keys %all_inputs;
        if (@states) {
            confess "input(s) not defined for from-state $from_state: "
              . join( ', ', @states );
        }
    }

    ( is_name($initial_state) && exists $all_from_states{$initial_state} )
      or confess
      'initial_state argument must be defined in the transitions argument';

    ( is_arrayref($final_states) && all { exists $all_from_states{$_} }
        @{$final_states} )
      or confess 'final_states argument must be an arrayref of states '
      . 'defined in the transitions argument';

    my $self = bless {}, $class;

    $self->{state}        = $initial_state;
    $self->{final_states} = { map { $_ => 1 } @{ $final_states } };
    $self->{transitions}  = $transitions;

    return $self;
}

=head1 INSTANCE METHODS

=head2 state

Get the current state.

    my $state = $dfa->state();

=cut

sub state {
    my $self = shift;
    return $self->{state};
}

=head2 is_final

Test if the current state is one of the final states.

    if ( $dfa->is_final() ) {
        print "accepted!\n";
    }

=cut

sub is_final {
    my $self = shift;

    return exists $self->{final_states}{$self->{state}};
}

=head2 process

Processes an input symbol.

    my $turnstile->process( "coin" );

Accepts an input symbol and updates the current state according to the previous
current state and the input symbol.

Returns the new current state.

Throws an exception if the input symbol is not recognized by this DFA.

=cut

sub process {
    my $self  = shift;
    my $input = shift;

    exists $self->{transitions}{ $self->{state} }{$input}
      or confess '$input must be a defined input';

    $self->{state} = $self->{transitions}{ $self->{state} }{$input};

    return $self->{state};
}

1;
