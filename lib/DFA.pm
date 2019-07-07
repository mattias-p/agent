package DFA;
use strict;
use warnings;

use Carp qw( confess );
use DFA::Util qw( is_transition_mapping is_name is_arrayref is_coderef );
use List::Util qw( all );

sub new {
    my ( $class, %args ) = @_;

    my $transitions     = delete $args{transitions};
    my $initial_state   = delete $args{initial_state};
    my $final_states    = delete $args{final_states};
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
        if ( @states ) {
          confess
          "input(s) not defined for from-state $from_state: " . join(', ', @states);

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

sub state {
    my $self = shift;
    return $self->{state};
}

sub is_final {
    my $self = shift;

    return exists $self->{final_states}{$self->{state}};
}

sub process {
    my $self  = shift;
    my $input = shift;

    exists $self->{transitions}{ $self->{state} }{$input}
      or confess '$input must be a defined input';

    $self->{state} = $self->{transitions}{ $self->{state} }{$input};

    return $self->{state};
}

1;
