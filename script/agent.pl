#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

use App::Allocator;
use App::Config;
use App::Agent qw( cmp_inputs $I_ALRM $I_CHLD $I_HUP $I_STEP $I_TERM $I_USR2 $S_LOAD );
use Cwd;
use File::Spec;
use Heap::Binary;
use Log::Any '$log';
use Log::Any::Adapter;
use Proc::Daemon;
use Readonly;
use Unix::AlarmQueue;
use Unix::Dispatcher;
use Unix::Idler;
use Unix::Signal qw( install_handler retrieve_caught uninstall_handlers );

Readonly my $log_file => File::Spec->catfile( getcwd, 'agent.log' );
Readonly my $pid_file => File::Spec->catfile( getcwd, 'agent.pid' );
Readonly my $out_file => File::Spec->catfile( getcwd, 'agent.out' );

Log::Any::Adapter->set( 'File', $log_file );

sub work {
    my $jid = shift;
    uninstall_handlers();    # reset signal handlers for child process
    sleep( 5 + rand 11 );    # pretend to do something
    return;
}

my $config = App::Config->new( p_fail => 0.2 );

if ( !$config->load() ) {
    say STDERR "Failed to load config";
    exit 1;
}

my $alarms = Unix::AlarmQueue->new();

my $dispatcher = Unix::Dispatcher->new(
    config => $config,
    action => \&work,
    p_fail => 0.2,
);

my $initial_state = $S_LOAD;

my $idler = Unix::Idler->new();

my $allocator = App::Allocator->new( p_fail => 0.1 );

my $agent = App::Agent->new(
    initial_state => $initial_state,
    alarms        => $alarms,
    allocator     => $allocator,
    config        => $config,
    dispatcher    => $dispatcher,
    idler         => $idler,
);

my $events = Heap::Binary->new( \&cmp_inputs );

my $daemon = Proc::Daemon->new();
my $pid    = $daemon->Init(
    {
        pid_file     => $pid_file,
        child_STDERR => $out_file,
        child_STDOUT => $out_file,
    }
);
if ($pid) {
    say STDERR "Started daemon (pid $pid)";

    exit;
}
elsif ( !defined $pid ) {
    say STDERR "Failed to start daemon";

    exit 1;
}

Log::Any::Adapter->set( 'File', $log_file );    # reopen after daemonization
$log->noticef( "***************************", $$ );
$log->noticef( "Started daemon (pid %s)", $$ );
$log->noticef( "State(%s)", $initial_state );

install_handler( 'ALRM' );
install_handler( 'CHLD' );
install_handler( 'HUP' );
install_handler( 'TERM' );
install_handler( 'USR2' );

while ( !$agent->is_final ) {
    my @events = $agent->process( $events->extract_min() // $I_STEP );

    $events->insert($_) for @events;
    $events->insert($I_ALRM) if retrieve_caught('ALRM');
    $events->insert($I_CHLD) if retrieve_caught('CHLD');
    $events->insert($I_HUP)  if retrieve_caught('HUP');
    $events->insert($I_TERM) if retrieve_caught('TERM');
    $events->insert($I_USR2) if retrieve_caught('USR2');
}

exit 0;
