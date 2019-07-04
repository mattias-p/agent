#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

use App::Agent qw( cmp_inputs $I_ALRM $I_CHLD $I_HUP $I_STEP $I_TERM $I_USR2 $S_LOAD );
use App::JobSource;
use App::Config;
use App::DB;
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

# to be executed in child processes before any real work takes place
sub setup_worker {
    uninstall_handlers();    # reset signal handlers
    srand($$);               # make sure workers don't all emit identical synthetic errors
    return;
}

my $config = App::Config->new( p_fail => 0.1 );

if ( !$config->load() ) {
    say STDERR "Failed to load config";
    exit 1;
}

{
    my $db = App::DB->connect( config => $config );

    for (1..10) {
        $db->unit_new();
    }

    $db->disconnect;
}

my $daemon = Proc::Daemon->new();
my $pid    = $daemon->Init(
    {
        work_dir     => getcwd,
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

my $alarms = Unix::AlarmQueue->new();

my $dispatcher = Unix::Dispatcher->new(
    config => $config,
    p_fail => 0.0,
);

my $initial_state = $S_LOAD;

my $idler = Unix::Idler->new();

my $db = App::DB->connect( config => $config );

my $job_source = App::JobSource->new(
    db     => $db,
    p_fail => 0.0,
);

my $agent = App::Agent->new(
    initial_state => $initial_state,
    db            => $db,
    alarms        => $alarms,
    job_source    => $job_source,
    config        => $config,
    dispatcher    => $dispatcher,
    idler         => $idler,
    setup_worker  => \&setup_worker,
    db_class      => 'App::DB',
);

my $events = Heap::Binary->new( \&cmp_inputs );


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

$db->disconnect();

exit 0;
