package Agent;
use strict;
use warnings;

use Carp qw( confess croak );
use DFA;
use Exporter qw( import );
use Log::Any qw( $log );
use Log::Any::Adapter;
use Readonly;
use Set::Ordered::BitVector;

our @EXPORT_OK = qw(
  create_dfa
  $S_INIT_START
  $S_INIT_SETUP
  $S_ACTIVE_LOAD
  $S_ACTIVE_SPAWN
  $S_ACTIVE_REAP
  $S_ACTIVE_EXPIRE
  $S_ACTIVE_IDLE
  $S_CLOSING_REAP
  $S_CLOSING_EXPIRE
  $S_CLOSING_IDLE
  $S_CLOSING_KILL_
  $S_FINAL_ERROR
  $S_FINAL_OK
  $I_EXPIRE
  $I_REAP
  $I_CLOSE
  $I_LOAD
  $I_SPAWN
  $I_STEP
  @INPUT_NAMES
);

Readonly our $S_INIT_START     => 'INIT_START';
Readonly our $S_INIT_SETUP     => 'INIT_SETUP';
Readonly our $S_ACTIVE_LOAD    => 'ACTIVE_LOAD';
Readonly our $S_ACTIVE_SPAWN   => 'ACTIVE_SPAWN';
Readonly our $S_ACTIVE_IDLE    => 'ACTIVE_IDLE';
Readonly our $S_ACTIVE_REAP    => 'ACTIVE_REAP';
Readonly our $S_ACTIVE_EXPIRE  => 'ACTIVE_EXPIRE';
Readonly our $S_CLOSING_IDLE   => 'CLOSING_IDLE';
Readonly our $S_CLOSING_REAP   => 'CLOSING_REAP';
Readonly our $S_CLOSING_EXPIRE => 'CLOSING_EXPIRE';
Readonly our $S_CLOSING_ACQUIT => 'CLOSING_ACQUIT';
Readonly our $S_FINAL_ERROR    => 'FINAL_ERROR';
Readonly our $S_FINAL_OK       => 'FINAL_OK';

Readonly my %ENTRY_ACTIONS => (
    $S_INIT_START     => \&do_noop,
    $S_INIT_SETUP     => \&do_setup,
    $S_ACTIVE_SPAWN   => \&do_spawn,
    $S_ACTIVE_IDLE    => \&do_idle,
    $S_ACTIVE_LOAD    => \&do_load,
    $S_ACTIVE_EXPIRE  => \&do_expire,
    $S_ACTIVE_REAP    => \&do_reap,
    $S_CLOSING_IDLE   => \&do_grace_idle,
    $S_CLOSING_EXPIRE => \&do_expire,
    $S_CLOSING_REAP   => \&do_reap,
    $S_CLOSING_ACQUIT => \&do_acquit,
    $S_FINAL_OK       => \&do_noop,
    $S_FINAL_ERROR    => \&do_noop,
);

Readonly our $I_ERROR  => 0;
Readonly our $I_ACQUIT => 1;
Readonly our $I_CLOSE  => 2;
Readonly our $I_EXPIRE => 3;
Readonly our $I_REAP   => 4;
Readonly our $I_LOAD   => 5;
Readonly our $I_SPAWN  => 6;
Readonly our $I_STEP   => 7;

Readonly our @INPUT_NAMES => qw(
  ERROR
  ACQUIT
  CLOSE
  EXPIRE
  REAP
  LOAD
  SPAWN
  STEP
);

sub create_dfa {
    return DFA->new(
        initial_state => $S_INIT_START,
        final_states  => [ $S_FINAL_ERROR, $S_FINAL_OK ],
        transitions   => {
            $S_INIT_START => {
                $I_ERROR  => $S_FINAL_ERROR,
                $I_EXPIRE => $S_INIT_SETUP,
                $I_REAP   => $S_INIT_SETUP,
                $I_ACQUIT => $S_FINAL_OK,
                $I_CLOSE  => $S_FINAL_OK,
                $I_LOAD   => $S_INIT_SETUP,
                $I_SPAWN  => $S_INIT_SETUP,
                $I_STEP   => $S_INIT_SETUP,
            },
            $S_INIT_SETUP => {
                $I_ERROR  => $S_FINAL_ERROR,
                $I_EXPIRE => $S_ACTIVE_SPAWN,
                $I_REAP   => $S_ACTIVE_SPAWN,
                $I_ACQUIT => $S_FINAL_OK,
                $I_CLOSE  => $S_FINAL_OK,
                $I_LOAD   => $S_ACTIVE_SPAWN,
                $I_SPAWN  => $S_ACTIVE_SPAWN,
                $I_STEP   => $S_ACTIVE_SPAWN,
            },
            $S_ACTIVE_SPAWN => {
                $I_ERROR  => $S_FINAL_ERROR,
                $I_EXPIRE => $S_ACTIVE_EXPIRE,
                $I_REAP   => $S_ACTIVE_REAP,
                $I_ACQUIT => $S_CLOSING_ACQUIT,
                $I_CLOSE  => $S_CLOSING_IDLE,
                $I_LOAD   => $S_ACTIVE_LOAD,
                $I_SPAWN  => $S_ACTIVE_SPAWN,
                $I_STEP   => $S_ACTIVE_IDLE,
            },
            $S_ACTIVE_IDLE => {
                $I_ERROR  => $S_FINAL_ERROR,
                $I_EXPIRE => $S_ACTIVE_EXPIRE,
                $I_REAP   => $S_ACTIVE_REAP,
                $I_ACQUIT => $S_CLOSING_ACQUIT,
                $I_CLOSE  => $S_CLOSING_IDLE,
                $I_LOAD   => $S_ACTIVE_LOAD,
                $I_SPAWN  => $S_ACTIVE_SPAWN,
                $I_STEP   => $S_ACTIVE_IDLE,
            },
            $S_ACTIVE_LOAD => {
                $I_ERROR  => $S_FINAL_ERROR,
                $I_EXPIRE => $S_ACTIVE_EXPIRE,
                $I_REAP   => $S_ACTIVE_REAP,
                $I_ACQUIT => $S_CLOSING_ACQUIT,
                $I_CLOSE  => $S_CLOSING_IDLE,
                $I_LOAD   => $S_ACTIVE_LOAD,
                $I_SPAWN  => $S_ACTIVE_SPAWN,
                $I_STEP   => $S_ACTIVE_SPAWN,
            },
            $S_ACTIVE_EXPIRE => {
                $I_ERROR  => $S_FINAL_ERROR,
                $I_EXPIRE => $S_ACTIVE_EXPIRE,
                $I_REAP   => $S_ACTIVE_REAP,
                $I_ACQUIT => $S_CLOSING_ACQUIT,
                $I_CLOSE  => $S_CLOSING_IDLE,
                $I_LOAD   => $S_ACTIVE_LOAD,
                $I_SPAWN  => $S_ACTIVE_SPAWN,
                $I_STEP   => $S_ACTIVE_SPAWN,
            },
            $S_ACTIVE_REAP => {
                $I_ERROR  => $S_FINAL_ERROR,
                $I_EXPIRE => $S_ACTIVE_EXPIRE,
                $I_REAP   => $S_ACTIVE_REAP,
                $I_ACQUIT => $S_CLOSING_ACQUIT,
                $I_CLOSE  => $S_CLOSING_IDLE,
                $I_LOAD   => $S_ACTIVE_LOAD,
                $I_SPAWN  => $S_ACTIVE_SPAWN,
                $I_STEP   => $S_ACTIVE_SPAWN,
            },
            $S_CLOSING_IDLE => {
                $I_ERROR  => $S_FINAL_ERROR,
                $I_EXPIRE => $S_CLOSING_EXPIRE,
                $I_REAP   => $S_CLOSING_REAP,
                $I_ACQUIT => $S_CLOSING_ACQUIT,
                $I_CLOSE  => $S_FINAL_OK,
                $I_LOAD   => $S_CLOSING_IDLE,
                $I_SPAWN  => $S_CLOSING_IDLE,
                $I_STEP   => $S_CLOSING_IDLE,
            },
            $S_CLOSING_REAP => {
                $I_ERROR  => $S_FINAL_ERROR,
                $I_EXPIRE => $S_CLOSING_EXPIRE,
                $I_REAP   => $S_CLOSING_REAP,
                $I_ACQUIT => $S_CLOSING_ACQUIT,
                $I_CLOSE  => $S_CLOSING_IDLE,
                $I_LOAD   => $S_CLOSING_IDLE,
                $I_SPAWN  => $S_CLOSING_IDLE,
                $I_STEP   => $S_CLOSING_IDLE,
            },
            $S_CLOSING_EXPIRE => {
                $I_ERROR  => $S_FINAL_ERROR,
                $I_EXPIRE => $S_CLOSING_EXPIRE,
                $I_REAP   => $S_CLOSING_REAP,
                $I_ACQUIT => $S_CLOSING_ACQUIT,
                $I_CLOSE  => $S_CLOSING_IDLE,
                $I_LOAD   => $S_CLOSING_IDLE,
                $I_SPAWN  => $S_CLOSING_IDLE,
                $I_STEP   => $S_CLOSING_IDLE,
            },
            $S_CLOSING_ACQUIT => {
                $I_ERROR  => $S_FINAL_ERROR,
                $I_EXPIRE => $S_CLOSING_EXPIRE,
                $I_REAP   => $S_CLOSING_REAP,
                $I_ACQUIT => $S_CLOSING_ACQUIT,
                $I_CLOSE  => $S_CLOSING_IDLE,
                $I_LOAD   => $S_CLOSING_IDLE,
                $I_SPAWN  => $S_CLOSING_IDLE,
                $I_STEP   => $S_CLOSING_IDLE,
            },
            $S_FINAL_OK => {
                $I_ERROR  => $S_FINAL_OK,
                $I_EXPIRE => $S_FINAL_OK,
                $I_REAP   => $S_FINAL_OK,
                $I_ACQUIT => $S_FINAL_OK,
                $I_CLOSE  => $S_FINAL_OK,
                $I_LOAD   => $S_FINAL_OK,
                $I_SPAWN  => $S_FINAL_OK,
                $I_STEP   => $S_FINAL_OK,
            },
            $S_FINAL_ERROR => {
                $I_ERROR  => $S_FINAL_ERROR,
                $I_EXPIRE => $S_FINAL_ERROR,
                $I_REAP   => $S_FINAL_ERROR,
                $I_ACQUIT => $S_FINAL_ERROR,
                $I_CLOSE  => $S_FINAL_ERROR,
                $I_LOAD   => $S_FINAL_ERROR,
                $I_SPAWN  => $S_FINAL_ERROR,
                $I_STEP   => $S_FINAL_ERROR,
            },
        }
    );
}

sub new {
    my ( $class, %args ) = @_;
    my $config_loader = delete $args{config_loader};
    my $job_source    = delete $args{job_source};
    my $task_manager  = delete $args{task_manager};
    my $idler         = delete $args{idler};
    my $db_class      = delete $args{db_class};
    my $log_adapter   = delete $args{log_adapter};
    my $daemonizer    = delete $args{daemonizer};
    my $signals       = delete $args{signals};
    my $init_daemon   = delete $args{init_daemon};
    !%args
      or confess 'unrecognized arguments';

    my $lifecycle = create_dfa();

    my $self = bless {}, $class;

    $self->{config_loader} = $config_loader;
    $self->{daemonizer}    = $daemonizer;
    $self->{db_class}      = $db_class;
    $self->{task_manager}  = $task_manager;
    $self->{idler}         = $idler;
    $self->{job_source}    = $job_source;
    $self->{lifecycle}     = $lifecycle;
    $self->{log_adapter}   = $log_adapter;
    $self->{signals}       = $signals;
    $self->{init_daemon}   = $init_daemon;

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

    my $input_flags = Set::Ordered::BitVector->new();

    eval {
        while ( !$self->is_final ) {
            my $input = $input_flags->pop_min // $I_STEP;
            my $new_input = $self->process($input);
            $input_flags->insert($new_input);

            $self->{signals}->update();
            $self->{task_manager}->poll();

            if ( $self->{signals}->was_caught('HUP') ) {
                $input_flags->insert($I_LOAD);
            }
            if ( $self->{signals}->was_caught('QUIT') ) {
                $input_flags->insert($I_ACQUIT);
            }
            if ( $self->{signals}->was_caught('TERM') ) {
                $input_flags->insert($I_CLOSE);
            }
            if ( $self->{signals}->was_caught('USR2') ) {
                $input_flags->insert($I_SPAWN);
            }
            if ( $self->{task_manager}->has_overdue_tasks() ) {
                $input_flags->insert($I_EXPIRE);
            }
            if ( $self->{task_manager}->has_terminated_tasks() ) {
                $input_flags->insert($I_REAP);
            }
        }
    };
    if ($@) {
        $log->criticalf( 'uncaught exception in agent: %s', $@ );
        return 2;
    }

    if ( $self->state eq $S_FINAL_OK ) {
        return 0;
    }
    elsif ( $self->state eq $S_FINAL_ERROR ) {
        return 1;
    }
    else {
        $log->warn( 'unexpected final state: %s', $self->state );
        return 2;
    }
}

sub process {
    my $self  = shift;
    my $input = shift;

    my $state = $self->{lifecycle}->process($input);

    $log->infof( "input(%s) -> state(%s)", $INPUT_NAMES[$input], $state );
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

    $self->{config} = $self->{config_loader}->load()
      or croak "config loading failed";

    $log->info("testing database connection");
    {
        my $db = $self->{db_class}->connect( config => $self->{config} )
          or croak "database connection failed";
        $db->disconnect;
    }

    $log->info("daemonizing");
    my $pid = $self->{daemonizer}->daemonize();
    if ($pid) {
        $log->info("started daemon (pid $pid)");
        exit 0;  # exit parent process
    }
    elsif ( !defined $pid ) {
        croak "failed to start daemon";
    }

    # configure logging for daemon process
    Log::Any::Adapter->set( @{ $self->{log_adapter} } );

    $log->info("establishing database connection");
    my $db = $self->{db_class}->connect( config => $self->{config} )
      or croak "database reconnection failed";
    $self->{job_source}->set_db($db);

    $log->info("initializing daemon");
    $self->{init_daemon}();

    return $I_STEP;
}

sub do_load {
    my $self = shift;

    $log->info("loading config candidate");

    my $config = $self->{config_loader}->load();

    if ( !$config ) {
        $log->warn("config loading failed, keeping old config");
        return $I_STEP;
    }

    $log->info("connecting to database");

    my $db = $self->{db_class}->connect( config => $config );

    if (!$db) {
        $log->warn("database connection failed, keeping old config and database connection");
        return $I_STEP;
    }

    $log->info("adopting new configuration file and database connection");
    $self->{config} = $config;
    $self->{job_source}->set_db($db);
    $self->{config}->update_task_manager( $self->{task_manager} );

    return $I_STEP;
}

sub do_spawn {
    my $self = shift;

    if ( $self->{task_manager}->active_task_count >= $self->{config}->max_workers ) {
        $log->warn("no worker");
        return $I_STEP;
    }

    my $job = $self->{job_source}->claim_job();
    if ( !$job ) {
        $log->infof("no jobs");
        return $I_STEP;
    }

    my $pid = $self->{task_manager}->add_task(
        $self->{config}->timeout(),
        $job,
        sub {
            eval {
                for my $signame ( $self->{signals}->all_signals() ) {
                    $self->{signals}->set_handler( $signame, 'IGNORE' );
                }
                my $config   = $self->{config};
                my $db_class = $self->{db_class};
                $self->forget_everyting();
                srand($$);

                my $db = $db_class->connect( config => $config );
                $job->set_db($db);

                $log->infof( "job(%s:%s) starting work",
                    $job->item_id, $job->job_id );
                $job->run();

                $log->infof( "job(%s:%s) completed work, releasing it",
                    $job->item_id, $job->job_id );
                $job->release();
            };
            if ($@) {
                $log->criticalf('job(%s:%s) threw exception: %s', $job->item_id, $job->job_id, $@ );
                return 1;
            }

            return 0;
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

    return $I_SPAWN;
}

sub do_reap {
    my $self = shift;

    my %jobs = $self->{task_manager}->reap_terminated_tasks();
    for my $pid ( keys %jobs ) {
        my ( $wait_status, $job ) = @{ $jobs{$pid} };
        my $severity =
            ( $wait_status->is_not_found ) ? "error"
          : ( $wait_status->is_exit_ok )   ? "info"
          : ( $wait_status->is_stopsig )   ? "notice"
          :                                  "warn";

        my $is_severity = "is_$severity";
        if ( $log->$is_severity() ) {
            my $reason = $wait_status->message;
            $log->$severity( "worker($pid) $reason, releasing job("
                  . $job->item_id . ":"
                  . $job->job_id
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

sub do_grace_idle {
    my $self = shift;
    if ( $self->{task_manager}->has_live_workers ) {
        $self->do_idle;
        return $I_STEP;
    }
    else {
        return $I_CLOSE;
    }
}

sub do_expire {
    my $self = shift;

    my %jobs = $self->{task_manager}->terminate_tasks( treshold => time() );

    for my $pid ( keys %jobs ) {
        my $job = $jobs{$pid};
        $log->infof( "overdue worker(%s) killed, releasing job(%s:%s)",
            $pid, $job->item_id, $job->job_id );
        $job->release();
    }

    return $I_STEP;
}

sub do_acquit {
    my $self = shift;

    my %jobs = $self->{task_manager}->terminate_tasks( treshold => undef );

    for my $pid ( keys %jobs ) {
        my $job = $jobs{$pid};
        $log->infof( "worker(%s) killed, releasing job(%s:%s)",
            $pid, $job->item_id, $job->job_id );
        $job->release();
    }

    return $I_STEP;
}

sub do_noop {
    my $self = shift;

    return $I_STEP;
}

1;
