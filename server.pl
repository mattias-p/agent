#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

use Alarm;
use Allocator;
use Config;
use Dispatcher;
use Heap::Binary;
use Readonly;
use Server qw( cmp_inputs $I_ZERO $I_CHLD $I_ALRM $I_USR1 $I_HUP $I_TERM );
use Signal qw( install_handler retrieve_caught );

say "$$";
install_handler( 'ALRM' );
install_handler( 'CHLD' );
install_handler( 'HUP' );
install_handler( 'TERM' );
install_handler( 'USR1' );

my $server = Server->new(
    config     => Config->new(),
    allocator  => Allocator->new(),
    dispatcher => Dispatcher->new(),
    alarm      => Alarm->new(),
);

my $events = Heap::Binary->new( \&cmp_inputs );
$events->insert($I_HUP);

while ( $server->is_alive ) {
    my @events = $server->process( $events->extract_min() // $I_ZERO );

    $events->insert($_) for @events;
    $events->insert($I_ALRM) if retrieve_caught('ALRM');
    $events->insert($I_CHLD) if retrieve_caught('CHLD');
    $events->insert($I_HUP)  if retrieve_caught('HUP');
    $events->insert($I_TERM) if retrieve_caught('TERM');
    $events->insert($I_USR1) if retrieve_caught('USR1');
}
