#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

use Readonly;
use Heap::Binary;
use POSIX qw( pause );
use ServerFSM qw( new_server_fsm cmp_inputs $S_LOAD $S_RUN $S_REAP $S_WATCH $S_SLEEP $S_REAP_GRACE $S_WATCH_GRACE $S_SLEEP_GRACE $S_SHUTDOWN $S_EXIT $I_ZERO $I_DONE $I_CHLD $I_ALRM $I_USR1 $I_HUP $I_TERM $I_EXIT );
use Signal qw( install_handler retrieve_caught );

my %actions = (
    $S_LOAD => sub {
        say "Loading";
        return;
    },
    $S_RUN => sub {
        say "Running";
        return rand() < 0.25 ? $I_DONE : ();
    },
    $S_REAP => sub {
        say "Reaping";
        return;
    },
    $S_WATCH => sub {
        say "Watching";
        return;
    },
    $S_SLEEP => sub {
        say "Sleeping";
        pause;
        return;
    },
    $S_REAP_GRACE => sub {
        say "Reaping during gracefull shutdown";
        return;
    },
    $S_WATCH_GRACE => sub {
        say "Watching during gracefull shutdown";
        return;
    },
    $S_SLEEP_GRACE => sub {
        say "Sleeping during gracefull shutdown";
        return;
    },
    $S_SHUTDOWN => sub {
        say "Shutting down forcefully";
        return;
    },
);

say "$$";
install_handler( 'ALRM' );
install_handler( 'CHLD' );
install_handler( 'HUP' );
install_handler( 'TERM' );
install_handler( 'USR1' );

my $event_stream = Heap::Binary->new( \&cmp_inputs );
my $fsm          = new_server_fsm();
while ( $fsm->current ne $S_EXIT ) {
    my @events = $actions{ $fsm->current }->();

    $event_stream->insert($_) for @events;
    $event_stream->insert($I_ALRM) if retrieve_caught('ALRM');
    $event_stream->insert($I_CHLD) if retrieve_caught('CHLD');
    $event_stream->insert($I_HUP)  if retrieve_caught('HUP');
    $event_stream->insert($I_TERM) if retrieve_caught('TERM');
    $event_stream->insert($I_USR1) if retrieve_caught('USR1');

    my $input = $event_stream->extract_min() // $I_ZERO;

    $fsm->process($input);
}
