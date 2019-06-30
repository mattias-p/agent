package FSM;
use strict;
use warnings;
use feature 'say';

use Carp qw( confess );
use FSM::Util;
use List::Util qw( all );

sub new {
    my ( $class, %args ) = @_;

    my $transitions     = delete $args{transitions};
    my $initial_state   = delete $args{initial_state};
    my $final_states    = delete $args{final_states};
    my $output_function = delete $args{output_function};
    !%args or confess 'unexpected args';

    $final_states //= [];
    $output_function //= sub { $_[0] };

    FSM::Util::is_transition_mapping($transitions)
      or confess 'transitions argument must be a valid transition mapping';
    my %defined_states =
      map { $_ => 1 } keys %{ [ values %{$transitions} ]->[0] };

      ( FSM::Util::is_name($initial_state) && exists $defined_states{$initial_state} )
      or confess
      'initial_state argument must be defined in the transitions argument';

      ( FSM::Util::is_arrayref($final_states) && all { exists $defined_states{$_} }
        @{$final_states} )
      or confess 'final_states argument must be an arrayref of states '
      . 'defined in the transitions argument';

    my $self = bless {}, $class;

    $self->{state}        = $initial_state;
    $self->{final_states} = { map { $_ => 1 } @{ $final_states } };
    $self->{transitions}  = $transitions;
    $self->{output}       = $output_function;

    return $self;
}

sub current {
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

    exists $self->{transitions}{$input}
      or confess '$input must be a defined input';

    $self->{state} = $self->{transitions}{$input}{ $self->{state} };

    say "Input: " . $input;
    say "State: " . $self->{state};

    return $self->{output}->( $self->{state}, $input );
}

1;
