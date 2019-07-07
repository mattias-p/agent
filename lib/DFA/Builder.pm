package DFA::Builder;
use strict;
use warnings;

use Carp qw( confess );
use DFA;
use DFA::Util qw( is_name is_state_mapping );
use List::Util qw( all );
use Storable qw( dclone );

sub new {
    my $class = shift;

    my $self = bless {}, $class;

    $self->{transitions} = {};

    return $self;
}

sub define_state {
    my ( $self, $from_state, %transitions ) = @_;

    is_name($from_state)
      or confess 'from_state argument must be a valid input name';

    is_state_mapping( \%transitions )
      or confess '%transitions argument must be a valid state mapping';

    $self->{reference_inputs} //= \%transitions;

    ( !exists $self->{transitions}{$from_state} )
      or confess 'from-state already defined';

    all { exists $self->{reference_inputs}{$_} } keys %transitions
      or confess
      'transitions argument contains one or more unrecognized inputs';

    all { exists $transitions{$_} } keys %{ $self->{reference_inputs} }
      or confess 'transitions argument is missing one or more inputs';

    $self->{transitions}{$from_state} = \%transitions;

    return;
}

sub build {
    my ( $self, %args ) = @_;

    my $initial_state = delete $args{initial_state};
    my $final_states  = delete $args{final_states};
    my $class         = delete $args{class};

    !%args or confess 'unrecognized arguments';

    $final_states //= [];
    $class //= 'DFA';

    my $fsm = DFA::new(
        $class,
        initial_state => $initial_state,
        final_states  => $final_states,
        transitions   => dclone $self->{transitions},
    );

    return $fsm;
}

1;
