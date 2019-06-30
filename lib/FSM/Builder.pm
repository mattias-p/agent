package FSM::Builder;
use strict;
use warnings;

use Carp qw( confess );
use FSM;
use FSM::Util qw( is_name is_state_mapping );
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
    my $final_states = delete $args{final_states};
    my $output_function = delete $args{output_function};

    !%args or confess 'unrecognized arguments';

    $final_states //= [];
    $output_function //= sub { $_[0] };

    exists $self->{reference_states} or confess 'no transitions were defined';

    exists $self->{reference_states}{$initial_state} or confess 'unrecognized state specified as initial state';
    all { exists $self->{reference_states}{$_} } @{ $final_states } or confess 'unrecognized state among final states';

    ref $output_function eq 'CODE' or confess 'output_function argument must be a coderef';

    my $fsm = FSM->new(
        initial_state   => $initial_state,
        final_states    => $final_states,
        transitions     => dclone $self->{transitions},
        output_function => $output_function,
    );

    return $fsm;
}

1;
