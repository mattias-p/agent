#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

use Agent;
use Cwd;
use Example::ConfigLoader;
use Example::DB;
use Example::JobSource;
use File::Spec;
use Readonly;
use Unix::AlarmQueue;
use Unix::Daemonizer;
use Unix::Dispatcher;
use Unix::Idler;
use Unix::Signal;

my $agent = do {
    Readonly my $pid_file    => File::Spec->catfile( getcwd, 'example.pid' );
    Readonly my $out_file    => File::Spec->catfile( getcwd, 'example.out' );
    Readonly my $log_file    => File::Spec->catfile( getcwd, 'example.log' );
    Readonly my $config_file => File::Spec->catfile( getcwd, 'example.conf' );

    my $config_loader = Example::ConfigLoader->new(
        p_fail      => 0.1,
        config_file => $config_file,
    );

    # Inject some new jobs into the job source
    {
        if ( my $config = $config_loader->load() ) {
            my $db = Example::DB->connect( config => $config );

            $db->create_schema;

            for ( 1 .. 10 ) {
                $db->unit_new();
            }

            $db->disconnect;
        }
    }

    my $db_class = 'Example::DB';

    my $log_adapter = [ 'File', $log_file ];

    my $daemonizer = Unix::Daemonizer->new(
        work_dir => getcwd,
        pid_file => $pid_file,
        out_file => $out_file,
    );

    my $alarms = Unix::AlarmQueue->new();

    my $dispatcher = Unix::Dispatcher->new(
        p_fail => 0.0,
    );

    my $idler = Unix::Idler->new();

    my $job_source = Example::JobSource->new(
        p_fail => 0.0,
    );

    my $signals = Unix::Signal->new();

    Agent->new(
        alarms        => $alarms,
        config_loader => $config_loader,
        daemonizer    => $daemonizer,
        db_class      => $db_class,
        dispatcher    => $dispatcher,
        idler         => $idler,
        job_source    => $job_source,
        log_adapter   => $log_adapter,
        signals       => $signals,
    );
};

my $exitcode = $agent->run();

exit($exitcode);
