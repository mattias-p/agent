#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

use Alarm;
use Allocator;
use Config;
use Dispatcher;
use Heap::Binary;
use POSIX qw( pause );
use Readonly;
use ServerFSM qw( new_server_fsm cmp_inputs $S_EXIT $I_ZERO $I_CHLD $I_ALRM $I_USR1 $I_HUP $I_TERM );
use Signal qw( install_handler retrieve_caught );

say "$$";
install_handler( 'ALRM' );
install_handler( 'CHLD' );
install_handler( 'HUP' );
install_handler( 'TERM' );
install_handler( 'USR1' );

my $event_stream = Heap::Binary->new( \&cmp_inputs );
my $fsm          = new_server_fsm();
my $agent = ServerFSM->new(
    config     => Config->new(),
    allocator  => Allocator->new(),
    dispatcher => Dispatcher->new(),
    alarm      => Alarm->new(),
);
while ( $fsm->current ne $S_EXIT ) {
    my @events = $agent->act( $fsm->current );

    $event_stream->insert($_) for @events;
    $event_stream->insert($I_ALRM) if retrieve_caught('ALRM');
    $event_stream->insert($I_CHLD) if retrieve_caught('CHLD');
    $event_stream->insert($I_HUP)  if retrieve_caught('HUP');
    $event_stream->insert($I_TERM) if retrieve_caught('TERM');
    $event_stream->insert($I_USR1) if retrieve_caught('USR1');

    my $input = $event_stream->extract_min() // $I_ZERO;

    $fsm->process($input);
}
