#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

use App::Agent;
use App::JobSource;
use App::Config;
use App::DB;
use Cwd;
use Daemonizer;
use File::Spec;
use Readonly;
use Unix::AlarmQueue;
use Unix::Dispatcher;
use Unix::Idler;
use Unix::Signal;

# Inject some new jobs in the job source
{
    my $config = App::Config->new( p_fail => 0.1 );

    if ( !$config->load() ) {
        say STDERR "Failed to load config";
        exit 1;
    }

    my $db = App::DB->connect( config => $config );

    for (1..10) {
        $db->unit_new();
    }

    $db->disconnect;
}

my $agent = do {
    Readonly my $pid_file => File::Spec->catfile( getcwd, 'agent.pid' );
    Readonly my $out_file => File::Spec->catfile( getcwd, 'agent.out' );
    Readonly my $log_file => File::Spec->catfile( getcwd, 'agent.log' );

    my $log_adapter = [ 'File', $log_file ];

    my $config = App::Config->new(
        p_fail => 0.1,
    );

    my $daemonizer = Daemonizer->new(
        work_dir => getcwd,
        pid_file => $pid_file,
        out_file => $out_file,
    );

    my $alarms = Unix::AlarmQueue->new();

    my $dispatcher = Unix::Dispatcher->new(
        config => $config,
        p_fail => 0.0,
    );

    my $idler = Unix::Idler->new();

    my $job_source = App::JobSource->new(
        p_fail => 0.0,
    );

    my $signals = Unix::Signal->new();

    App::Agent->new(
        alarms       => $alarms,
        config       => $config,
        daemonizer   => $daemonizer,
        db_class     => 'App::DB',
        dispatcher   => $dispatcher,
        idler        => $idler,
        job_source   => $job_source,
        log_adapter  => $log_adapter,
        signals      => $signals,
    );
};

my $exitcode = $agent->run();

exit($exitcode);
