package DFA::Util;
use strict;
use warnings;

use Exporter qw( import );
use List::Util qw( all );

our @EXPORT_OK = qw( is_arrayref is_coderef is_name is_state_mapping is_transition_mapping );

sub diff_keys {
    my $left  = shift;
    my $right = shift;

    my %delta;
    $delta{$_}++ for keys %{$left};
    $delta{$_}-- for keys %{$right};

    return %delta;
}

sub left_only {
    my %delta = @_;
    grep { $delta{$_} > 0 } keys %delta;
}

sub right_only {
    my %delta = @_;
    grep { $delta{$_} < 0 } keys %delta;
}

sub is_arrayref {
    my $value = shift;
    return 0 unless ref $value eq 'ARRAY';
    return 1;
}

sub is_coderef {
    my $value = shift;
    return 0 unless ref $value eq 'CODE';
    return 1;
}

sub is_name {
    my $value = shift;
    return 0 unless defined $value;
    return 0 unless ref $value eq '';
    return $value =~ /^[[:graph:]]([ [:graph:]]*[[:graph:]])?$/;
}

sub is_state_mapping {
    my $state_mapping = shift;
    return 0 unless ref $state_mapping eq 'HASH';
    return 0 unless %{ $state_mapping };
    return 0 unless all { is_name( $_ ) } keys %{ $state_mapping };
    return 0 unless all { is_name( $_ ) } values %{ $state_mapping };
    return 1;
}

sub is_transition_mapping {
    my $trans_mapping = shift;

    return 0 unless ref $trans_mapping eq 'HASH';
    return 0 unless %{ $trans_mapping };
    return 0 unless all { is_name( $_ ) } keys %{ $trans_mapping };
    return 0 unless all { is_state_mapping( $_ ) } values %{ $trans_mapping };

    my $reference_input = [keys %{ $trans_mapping }]->[0];
    my $defined_states = $trans_mapping->{$reference_input};

    for my $state_mapping ( values %{ $trans_mapping } ) {
        my %from_delta = diff_keys $defined_states, $state_mapping;
        return 0 if left_only %from_delta;
        return 0 if right_only %from_delta;

        my %to_states = map { $_ => 1 } values %{ $state_mapping };
        my %to_delta = diff_keys $defined_states, \%to_states;
        return 0 if right_only %from_delta;
    }

    return 1;
}

1;
