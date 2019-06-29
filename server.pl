#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

use Readonly;
use Heap::Binary;
use FSM::Builder;

my $CAUGHT_SIGHUP  = 0;
my $CAUGHT_SIGTERM = 0;

Readonly my $S_START    => 'START';
Readonly my $S_LOAD     => 'LOAD';
Readonly my $S_RUN      => 'RUN';
Readonly my $S_GRACE    => 'GRACE';
Readonly my $S_SHUTDOWN => 'SHUTDOWN';
Readonly my $S_EXIT     => 'EXIT';

Readonly my $E_DEFAULT => 'default';
Readonly my $E_HUP     => 'hup';
Readonly my $E_TERM    => 'term';
Readonly my $E_EXIT    => 'exit';

Readonly my %PRIORITIES => (
    $E_EXIT => 0,
    $E_TERM => 1,
    $E_HUP => 2,
    $E_DEFAULT => 3,
);

sub catch_sighup {
    $SIG{HUP} = \&catch_sighup;
    $CAUGHT_SIGHUP = 1;
    return;
}

sub catch_sigterm {
    $SIG{TERM} = \&catch_sigterm;
    $CAUGHT_SIGTERM = 1;
    return;
}

sub new_server_fsm {
    my $builder = FSM::Builder->new();

    $builder->define_input(
        $E_DEFAULT => (
            $S_LOAD     => $S_RUN,
            $S_RUN      => $S_RUN,
            $S_GRACE    => $S_GRACE,
            $S_SHUTDOWN => $S_EXIT,
            $S_EXIT     => $S_EXIT,
        )
    );

    $builder->define_input(
        $E_HUP => (
            $S_LOAD     => $S_LOAD,
            $S_RUN      => $S_LOAD,
            $S_GRACE    => $S_GRACE,
            $S_SHUTDOWN => $S_EXIT,
            $S_EXIT     => $S_EXIT,
        )
    );

    $builder->define_input(
        $E_TERM => (
            $S_LOAD     => $S_GRACE,
            $S_RUN      => $S_GRACE,
            $S_GRACE    => $S_SHUTDOWN,
            $S_SHUTDOWN => $S_EXIT,
            $S_EXIT     => $S_EXIT,
        )
    );

    $builder->define_input(
        $E_EXIT => (
            $S_LOAD     => $S_SHUTDOWN,
            $S_RUN,     => $S_SHUTDOWN,
            $S_GRACE    => $S_SHUTDOWN,
            $S_SHUTDOWN => $S_EXIT,
            $S_EXIT     => $S_EXIT,
        )
    );

    return $builder->build( initial_state => $S_LOAD );
}

my $fsm = new_server_fsm();


my $input_queue =
  Heap::Binary->new( sub { $PRIORITIES{ $_[0] } <=> $PRIORITIES{ $_[1] } } );

my %actions = (
    $S_LOAD => sub {
        say "Loading";
        return;
    },
    $S_RUN => sub {
        say "Running";
        return;
    },
    $S_GRACE => sub {
        say "Shutting down gracefully";
        return;
    },
    $S_SHUTDOWN => sub {
        say "Shutting down forcefully";
        return;
    },
);

$SIG{HUP} = \&catch_sighup;
$SIG{HUP} = \&catch_sigterm;
while ($fsm->current ne $S_EXIT) {
    my @events = $actions{$fsm->current}->();
    for my $input ( @events ) {
        $input_queue->insert( $input );
    }

    if ( $CAUGHT_SIGHUP ) {
        $CAUGHT_SIGHUP = 0;
        $input_queue->insert( $E_HUP );
    }
    if ( $CAUGHT_SIGTERM ) {
        $CAUGHT_SIGTERM = 0;
        $input_queue->insert( $E_TERM );
    }

    my $input = $input_queue->extract_min() // $E_DEFAULT;
    $fsm->process( $input );
}
