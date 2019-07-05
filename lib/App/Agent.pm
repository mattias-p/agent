package App::Agent;
use strict;
use warnings;

use Carp qw( confess );
use EnumSet;
use Exporter qw( import );
use DFA::Builder;
use Log::Any qw( $log );
use Log::Any::Adapter;
use Readonly;
use Unix::Signal qw( install_handler retrieve_caught uninstall_handlers );

our @EXPORT_OK = qw(
  create_dfa
  $S_INIT_START
  $S_INIT_SETUP
  $S_ACTIVE_LOAD
  $S_ACTIVE_SPAWN
  $S_ACTIVE_REAP
  $S_ACTIVE_EXPIRE
  $S_ACTIVE_IDLE
  $S_GRACE_REAP
  $S_GRACE_EXPIRE
  $S_GRACE_IDLE
  $S_SHUTDOWN
  $S_FINAL_ERROR
  $S_FINAL_OK
  $I_EXPIRE
  $I_REAP
  $I_END
  $I_LOAD
  $I_SPAWN
  $I_STEP
);

Readonly our $S_INIT_START    => 'INIT_START';
Readonly our $S_INIT_SETUP    => 'INIT_SETUP';
Readonly our $S_ACTIVE_LOAD   => 'ACTIVE_LOAD';
Readonly our $S_ACTIVE_SPAWN  => 'ACTIVE_SPAWN';
Readonly our $S_ACTIVE_IDLE   => 'ACTIVE_IDLE';
Readonly our $S_ACTIVE_REAP   => 'ACTIVE_REAP';
Readonly our $S_ACTIVE_EXPIRE => 'ACTIVE_EXPIRE';
Readonly our $S_GRACE_IDLE    => 'GRACE_IDLE';
Readonly our $S_GRACE_REAP    => 'GRACE_REAP';
Readonly our $S_GRACE_EXPIRE  => 'GRACE_EXPIRE';
Readonly our $S_SHUTDOWN      => 'SHUTDOWN';
Readonly our $S_FINAL_ERROR   => 'FINAL_ERROR';
Readonly our $S_FINAL_OK      => 'FINAL_OK';

Readonly my %ENTRY_ACTIONS => (
    $S_INIT_START    => \&do_noop,
    $S_INIT_SETUP    => \&do_setup,
    $S_ACTIVE_LOAD   => \&do_load,
    $S_ACTIVE_SPAWN  => \&do_spawn,
    $S_ACTIVE_REAP   => \&do_reap,
    $S_ACTIVE_EXPIRE => \&do_expire,
    $S_ACTIVE_IDLE   => \&do_idle,
    $S_GRACE_REAP    => \&do_reap,
    $S_GRACE_EXPIRE  => \&do_expire,
    $S_GRACE_IDLE    => \&do_grace_idle,
    $S_SHUTDOWN      => \&do_shutdown,
    $S_FINAL_ERROR   => \&do_noop,
    $S_FINAL_OK      => \&do_noop,
);

Readonly our $I_EXPIRE => '0-EXPIRE';
Readonly our $I_REAP   => '1-REAP';
Readonly our $I_END    => '2-END';
Readonly our $I_LOAD   => '3-LOAD';
Readonly our $I_SPAWN  => '4-SPAWN';
Readonly our $I_STEP   => '5-STEP';

sub create_dfa {
    my $builder = DFA::Builder->new();

    $builder->define_input(
        $I_STEP => (
            $S_INIT_START    => $S_INIT_SETUP,
            $S_INIT_SETUP    => $S_ACTIVE_SPAWN,
            $S_ACTIVE_LOAD   => $S_ACTIVE_SPAWN,
            $S_ACTIVE_REAP   => $S_ACTIVE_SPAWN,
            $S_ACTIVE_EXPIRE => $S_ACTIVE_SPAWN,
            $S_ACTIVE_SPAWN  => $S_ACTIVE_IDLE,
            $S_ACTIVE_IDLE   => $S_ACTIVE_IDLE,
            $S_GRACE_IDLE    => $S_GRACE_IDLE,
            $S_GRACE_REAP    => $S_GRACE_IDLE,
            $S_GRACE_EXPIRE  => $S_GRACE_IDLE,
            $S_SHUTDOWN      => $S_SHUTDOWN,
            $S_FINAL_ERROR   => $S_FINAL_ERROR,
            $S_FINAL_OK      => $S_FINAL_OK,
        )
    );

    $builder->define_input(
        $I_SPAWN => (
            $S_INIT_START    => $S_INIT_SETUP,
            $S_INIT_SETUP    => $S_ACTIVE_SPAWN,
            $S_ACTIVE_LOAD   => $S_ACTIVE_SPAWN,
            $S_ACTIVE_REAP   => $S_ACTIVE_SPAWN,
            $S_ACTIVE_EXPIRE => $S_ACTIVE_SPAWN,
            $S_ACTIVE_SPAWN  => $S_ACTIVE_SPAWN,
            $S_ACTIVE_IDLE   => $S_ACTIVE_SPAWN,
            $S_GRACE_IDLE    => $S_GRACE_IDLE,
            $S_GRACE_REAP    => $S_GRACE_IDLE,
            $S_GRACE_EXPIRE  => $S_GRACE_IDLE,
            $S_SHUTDOWN      => $S_SHUTDOWN,
            $S_FINAL_ERROR   => $S_FINAL_ERROR,
            $S_FINAL_OK      => $S_FINAL_OK,
        )
    );

    $builder->define_input(
        $I_REAP => (
            $S_INIT_START    => $S_INIT_SETUP,
            $S_INIT_SETUP    => $S_ACTIVE_SPAWN,
            $S_ACTIVE_LOAD   => $S_ACTIVE_REAP,
            $S_ACTIVE_REAP   => $S_ACTIVE_REAP,
            $S_ACTIVE_EXPIRE => $S_ACTIVE_REAP,
            $S_ACTIVE_SPAWN  => $S_ACTIVE_REAP,
            $S_ACTIVE_IDLE   => $S_ACTIVE_REAP,
            $S_GRACE_IDLE    => $S_GRACE_REAP,
            $S_GRACE_REAP    => $S_GRACE_REAP,
            $S_GRACE_EXPIRE  => $S_GRACE_REAP,
            $S_SHUTDOWN      => $S_SHUTDOWN,
            $S_FINAL_ERROR   => $S_FINAL_ERROR,
            $S_FINAL_OK      => $S_FINAL_OK,
        )
    );

    $builder->define_input(
        $I_EXPIRE => (
            $S_INIT_START    => $S_INIT_SETUP,
            $S_INIT_SETUP    => $S_ACTIVE_SPAWN,
            $S_ACTIVE_LOAD   => $S_ACTIVE_EXPIRE,
            $S_ACTIVE_REAP   => $S_ACTIVE_EXPIRE,
            $S_ACTIVE_EXPIRE => $S_ACTIVE_EXPIRE,
            $S_ACTIVE_SPAWN  => $S_ACTIVE_EXPIRE,
            $S_ACTIVE_IDLE   => $S_ACTIVE_EXPIRE,
            $S_GRACE_IDLE    => $S_GRACE_EXPIRE,
            $S_GRACE_REAP    => $S_GRACE_EXPIRE,
            $S_GRACE_EXPIRE  => $S_GRACE_EXPIRE,
            $S_SHUTDOWN      => $S_SHUTDOWN,
            $S_FINAL_ERROR   => $S_FINAL_ERROR,
            $S_FINAL_OK      => $S_FINAL_OK,
        )
    );

    $builder->define_input(
        $I_LOAD => (
            $S_INIT_START    => $S_INIT_SETUP,
            $S_INIT_SETUP    => $S_ACTIVE_SPAWN,
            $S_ACTIVE_LOAD   => $S_ACTIVE_LOAD,
            $S_ACTIVE_REAP   => $S_ACTIVE_LOAD,
            $S_ACTIVE_EXPIRE => $S_ACTIVE_LOAD,
            $S_ACTIVE_SPAWN  => $S_ACTIVE_LOAD,
            $S_ACTIVE_IDLE   => $S_ACTIVE_LOAD,
            $S_GRACE_IDLE    => $S_GRACE_IDLE,
            $S_GRACE_REAP    => $S_GRACE_IDLE,
            $S_GRACE_EXPIRE  => $S_GRACE_IDLE,
            $S_SHUTDOWN      => $S_SHUTDOWN,
            $S_FINAL_ERROR   => $S_FINAL_ERROR,
            $S_FINAL_OK      => $S_FINAL_OK,
        )
    );

    $builder->define_input(
        $I_END => (
            $S_INIT_START    => $S_INIT_SETUP,
            $S_INIT_SETUP    => $S_FINAL_ERROR,
            $S_ACTIVE_LOAD   => $S_ACTIVE_SPAWN,
            $S_ACTIVE_REAP   => $S_GRACE_IDLE,
            $S_ACTIVE_EXPIRE => $S_GRACE_IDLE,
            $S_ACTIVE_SPAWN  => $S_GRACE_IDLE,
            $S_ACTIVE_IDLE   => $S_GRACE_IDLE,
            $S_GRACE_IDLE    => $S_SHUTDOWN,
            $S_GRACE_REAP    => $S_SHUTDOWN,
            $S_GRACE_EXPIRE  => $S_SHUTDOWN,
            $S_SHUTDOWN      => $S_FINAL_OK,
            $S_FINAL_ERROR   => $S_FINAL_ERROR,
            $S_FINAL_OK      => $S_FINAL_OK,
        )
    );
    return $builder->build(
        initial_state => $S_INIT_START,
        final_states  => [ $S_FINAL_ERROR, $S_FINAL_OK ],
    );
}

sub new {
    my ( $class, %args ) = @_;
    my $config      = delete $args{config};
    my $job_source  = delete $args{job_source};
    my $dispatcher  = delete $args{dispatcher};
    my $alarms      = delete $args{alarms};
    my $idler       = delete $args{idler};
    my $db_class    = delete $args{db_class};
    my $log_adapter = delete $args{log_adapter};
    my $daemonizer  = delete $args{daemonizer};
    !%args or confess 'unrecognized arguments';

    my $self = bless {}, $class;

    $self->{config}      = $config;
    $self->{job_source}  = $job_source;
    $self->{dispatcher}  = $dispatcher;
    $self->{alarms}      = $alarms;
    $self->{idler}       = $idler;
    $self->{db_class}    = $db_class;
    $self->{log_adapter} = $log_adapter;
    $self->{daemonizer}  = $daemonizer;
    $self->{lifecycle}   = create_dfa();

    return $self;
}

sub forget_everyting {
    my $self = shift;

    %{$self} = ();

    return;
}

sub run {
    my $self = shift;

    # configure logging for parent process
    Log::Any::Adapter->set( @{ $self->{log_adapter} } );
    $log->warnf( "*" x 78, $$ );
    $log->warnf( "*" x 78, $$ );
    $log->warnf( "*" x 78, $$ );
    $log->infof( "State(%s)", $self->state );

    my $events = EnumSet->new();

    while ( !$self->is_final ) {
        my @events = $self->process( $events->pop() // $I_STEP );

        $events->insert($_) for @events;

        if ( retrieve_caught('ALRM') ) {
            $log->debug("caught SIGALRM");
            $events->insert($I_EXPIRE);
        }
        if ( retrieve_caught('CHLD') ) {
            $log->debug("caught SIGCHLD");
            $events->insert($I_REAP);
        }
        if ( retrieve_caught('TERM') ) {
            $log->debug("caught SIGTERM");
            $events->insert($I_END);
        }
        if ( retrieve_caught('HUP') ) {
            $log->debug("caught SIGHUP");
            $events->insert($I_LOAD);
        }
        if ( retrieve_caught('USR2') ) {
            $log->debug("caught SIGUSR2");
            $events->insert($I_SPAWN);
        }
    }

    if ( $self->state eq $S_FINAL_OK ) {
        return 0;
    }
    elsif ( $self->state eq $S_FINAL_ERROR ) {
        return 1;
    }
    else {
        return 2;
    }
}

sub process {
    my $self  = shift;
    my $input = shift;

    my $state = $self->{lifecycle}->process($input);

    $log->infof( "input(%s) -> state(%s)", $input, $state );

    return $ENTRY_ACTIONS{$state}->($self);
}

sub state {
    my $self = shift;

    return $self->{lifecycle}->state;
}

sub is_final {
    my $self = shift;

    return $self->{lifecycle}->is_final;
}

sub do_setup {
    my $self = shift;

    Log::Any::Adapter->set( @{ $self->{log_adapter} } );

    $log->info("loading config");

    $self->{config}->load();

    if ( !$self->{config}->is_loaded ) {
        $log->critical("config loading failed");
        return $I_END;
    }

    $log->info("testing database connection");
    {
        my $db = $self->{db_class}->connect( config => $self->{config} );
        if (!$db) {
            $log->critical("database connection failed");
            return $I_END;
        }
        $db->disconnect;
    }

    $log->info("daemonizing");
    my $pid = $self->{daemonizer}->daemonize();
    if ($pid) {
        $log->info("started daemon (pid $pid)");
        exit 0;  # exit parent process
    }
    elsif ( !defined $pid ) {
        $log->critical("failed to start daemon");

        return $I_END;
    }

    # configure logging for daemon process
    Log::Any::Adapter->set( @{ $self->{log_adapter} } );

    $log->info("establishing database connection");
    my $db = $self->{db_class}->connect( config => $self->{config} );
    if (!$db) {
        $log->warn("database reconnection failed");
        return $I_END;
    }
    $self->{job_source}->set_db($db);

    $log->info("installing signal handlers");
    install_handler( 'ALRM' );
    install_handler( 'CHLD' );
    install_handler( 'HUP' );
    install_handler( 'TERM' );
    install_handler( 'USR2' );

    return $I_STEP;
}

sub do_load {
    my $self = shift;

    $log->info("loading config candidate");

    my $config = $self->{config_class}->load( $self->{config_file} );

    if ( !$config ) {
        if ( !$self->{config} ) {
            $log->critical("initial config loading failed");
            return $I_END;
        }

        $log->warn("config loading failed, keeping old config");
        return $I_STEP;
    }

    $log->info("connecting to database");

    my $db = $self->{db_class}->connect( config => $config );

    if (!$db) {
        if ( !$self->{config} ) {
            $log->critical("initial database connection failed");
            return $I_END;
        }

        $log->warn("database connection failed, keeping old config and database connection");
        return $I_STEP;
    }

    $log->info("adopting new config and database connection");
    $self->{config} = $config;
    $self->{job_source}->set_db($db);

    return $I_STEP;
}

sub do_spawn {
    my $self = shift;

    if ( !$self->{dispatcher}->can_spawn_worker ) {
        $log->warn("no workers");
        return $I_STEP;
    }

    my $job = $self->{job_source}->claim_job();
    if ( !$job ) {
        $log->infof("no jobs");
        return $I_STEP;
    }

    my $pid = $self->{dispatcher}->spawn(
        $job,
        sub {
            my $config   = $self->{config};
            my $db_class = $self->{db_class};
            $self->forget_everyting();
            uninstall_handlers();
            srand($$);

            my $db = $db_class->connect( config => $config );
            my $job = App::Job->new(
                db      => $db,
                job_id  => $job->job_id,
                item_id => $job->item_id,
            );

            $log->infof( "job(%s:%s) starting work",
                $job->item_id, $job->job_id );
            $job->run();

            $log->infof( "job(%s:%s) completed work, releasing it",
                $job->item_id, $job->job_id );
            $job->release();
            return;
        }
    );
    if ( !$pid ) {
        $log->infof( "job(%s:%s) spawning worker failed, releasing job",
            $job->item_id, $job->job_id );
        $job->release();
        return $I_SPAWN;
    }

    $log->infof( "job(%s:%s) claimed, worker(%s) spawned",
        $job->item_id, $job->job_id, $pid );
    $self->{alarms}->add_timeout( $self->{config}->timeout() );

    return $I_SPAWN;
}

sub do_reap {
    my $self = shift;
    my %jobs = $self->{dispatcher}->reap();
    for my $pid ( keys %jobs ) {
        my ( $severity, $details, $job ) = @{ $jobs{$pid} };
        my $is_severity = "is_$severity";
        if ( $log->$is_severity() ) {
            my $reason = $self->{dispatcher}->termination_reason($details);
            $log->$severity( "worker($pid) $reason, releasing job("
                  . $job->item_id . ":"
                  . $job->item_id
                  . ")" );
        }
        $job->release();
    }
    return $I_STEP;
}

sub do_idle {
    my $self = shift;
    $self->{idler}->idle();
    return $I_STEP;
}

sub do_expire {
    my $self = shift;

    $self->{alarms}->next_timeout();

    my %jobs = $self->{dispatcher}->kill_overdue();

    for my $pid ( keys %jobs ) {
        my $job = $jobs{$pid};
        $log->infof( "overdue worker(%s) killed, releasing job(%s:%s)",
            $pid, $job->item_id, $job->job_id );
        $job->release();
    }

    return $I_STEP;
}

sub do_grace_idle {
    my $self = shift;
    if ( $self->{dispatcher}->has_live_workers ) {
        $self->do_idle;
        return $I_STEP;
    }
    else {
        return $I_END;
    }
}

sub do_shutdown {
    my $self = shift;

    my %jobs = $self->{dispatcher}->shutdown();

    for my $pid ( keys %jobs ) {
        my ( $severity, $details, $job ) = @{ $jobs{$pid} };
        my $is_severity = "is_$severity";
        if ( $log->$is_severity() ) {
            my $reason = $self->{dispatcher}->termination_reason($details);
            $log->$severity( "worker($pid) $reason, releasing job("
                  . $job->item_id . ":"
                  . $job->job_id
                  . ")" );
        }
        $job->release();
    }
    return $I_END;
}

sub do_noop {
    my $self = shift;

    return $I_END;
}

1;
