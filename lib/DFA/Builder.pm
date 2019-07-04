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

sub define_input {
    my ( $self, $input, %transitions ) = @_;

    is_name( $input ) or confess 'argument must be a valid input name: $input';

    is_state_mapping( \%transitions ) or confess '%transitions argument must be a valid state mapping';

    $self->{reference_states} //= \%transitions;

    $self->{transitions}{$input} = \%transitions;

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

    exists $self->{reference_states} or confess 'no transitions were defined';

    exists $self->{reference_states}{$initial_state} or confess 'unrecognized state specified as initial state';
    all { exists $self->{reference_states}{$_} } @{ $final_states } or confess 'unrecognized state among final states';

    my $fsm = DFA::new(
        $class,
        initial_state => $initial_state,
        final_states  => $final_states,
        transitions   => dclone $self->{transitions},
    );

    return $fsm;
}

1;
