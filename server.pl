#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

use Readonly;
use Heap::Binary;
use ServerFSM qw( new_server_fsm $S_START $S_LOAD $S_RUN $S_GRACE $S_SHUTDOWN $S_EXIT $I_DEFAULT $I_HUP $I_TERM $I_EXIT );

my $CAUGHT_SIGHUP  = 0;
my $CAUGHT_SIGTERM = 0;

Readonly my %PRIORITIES => (
    $I_EXIT => 0,
    $I_TERM => 1,
    $I_HUP => 2,
    $I_DEFAULT => 3,
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
        $input_queue->insert( $I_HUP );
    }
    if ( $CAUGHT_SIGTERM ) {
        $CAUGHT_SIGTERM = 0;
        $input_queue->insert( $I_TERM );
    }

    my $input = $input_queue->extract_min() // $I_DEFAULT;
    $fsm->process( $input );
}
