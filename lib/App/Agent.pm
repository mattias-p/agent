package App::Agent;
use strict;
use warnings;

use Carp qw( confess );
use Exporter qw( import );
use DFA::Builder;
use Log::Any qw( $log );
use Readonly;

our @EXPORT_OK = qw( %INPUT_PRIORITIES $S_ACTIVE_LOAD $S_ACTIVE_RUN $S_ACTIVE_REAP $S_ACTIVE_TIMEOUT $S_ACTIVE_IDLE $S_GRACE_REAP $S_GRACE_TIMEOUT $S_GRACE_IDLE $S_SHUTDOWN $S_FINAL $I_STEP $I_DONE $I_CHLD $I_USR2 $I_ALRM $I_HUP $I_TERM $I_EXIT );

Readonly our $S_ACTIVE_LOAD    => 'ACTIVE_LOAD';
Readonly our $S_ACTIVE_RUN     => 'ACTIVE_RUN';
Readonly our $S_ACTIVE_IDLE    => 'ACTIVE_IDLE';
Readonly our $S_ACTIVE_REAP    => 'ACTIVE_REAP';
Readonly our $S_ACTIVE_TIMEOUT => 'ACTIVE_TIMEOUT';
Readonly our $S_GRACE_IDLE     => 'GRACE_IDLE';
Readonly our $S_GRACE_REAP     => 'GRACE_REAP';
Readonly our $S_GRACE_TIMEOUT  => 'GRACE_TIMEOUT';
Readonly our $S_SHUTDOWN       => 'SHUTDOWN';
Readonly our $S_FINAL          => 'FINAL';

Readonly my %ENTRY_ACTIONS => (
    $S_ACTIVE_LOAD    => \&do_load,
    $S_ACTIVE_RUN     => \&do_run,
    $S_ACTIVE_REAP    => \&do_reap,
    $S_ACTIVE_TIMEOUT => \&do_timeout,
    $S_ACTIVE_IDLE    => \&do_idle,
    $S_GRACE_REAP     => \&do_reap,
    $S_GRACE_TIMEOUT  => \&do_timeout,
    $S_GRACE_IDLE     => \&do_grace_idle,
    $S_SHUTDOWN       => \&do_shutdown,
    $S_FINAL          => \&do_final,
);

Readonly our $I_EXIT => 'EXIT';
Readonly our $I_DONE => 'DONE';
Readonly our $I_TERM => 'TERM';
Readonly our $I_CHLD => 'CHLD';
Readonly our $I_HUP  => 'HUP';
Readonly our $I_ALRM => 'ALRM';
Readonly our $I_USR2 => 'USR2';
Readonly our $I_STEP => 'STEP';

Readonly our %INPUT_PRIORITIES => (
    $I_EXIT => 0,
    $I_DONE => 1,
    $I_TERM => 2,
    $I_CHLD => 3,
    $I_ALRM => 4,
    $I_HUP  => 5,
    $I_USR2 => 6,
    $I_STEP => 7,
);

Readonly my $BUILDER => DFA::Builder->new();

$BUILDER->define_input(
    $I_STEP => (
        $S_ACTIVE_RUN     => $S_ACTIVE_RUN,
        $S_ACTIVE_IDLE    => $S_ACTIVE_RUN,
        $S_ACTIVE_LOAD    => $S_ACTIVE_RUN,
        $S_ACTIVE_REAP    => $S_ACTIVE_RUN,
        $S_ACTIVE_TIMEOUT => $S_ACTIVE_RUN,
        $S_GRACE_IDLE     => $S_GRACE_IDLE,
        $S_GRACE_REAP     => $S_GRACE_IDLE,
        $S_GRACE_TIMEOUT  => $S_GRACE_IDLE,
        $S_SHUTDOWN       => $S_SHUTDOWN,
        $S_FINAL          => $S_FINAL,
    )
);

$BUILDER->define_input(
    $I_DONE => (
        $S_ACTIVE_RUN     => $S_ACTIVE_IDLE,
        $S_ACTIVE_IDLE    => $S_ACTIVE_RUN,
        $S_ACTIVE_LOAD    => $S_ACTIVE_RUN,
        $S_ACTIVE_REAP    => $S_ACTIVE_RUN,
        $S_ACTIVE_TIMEOUT => $S_ACTIVE_RUN,
        $S_GRACE_IDLE     => $S_FINAL,
        $S_GRACE_REAP     => $S_FINAL,
        $S_GRACE_TIMEOUT  => $S_FINAL,
        $S_SHUTDOWN       => $S_FINAL,
        $S_FINAL          => $S_FINAL,
    )
);

$BUILDER->define_input(
    $I_CHLD => (
        $S_ACTIVE_RUN     => $S_ACTIVE_REAP,
        $S_ACTIVE_IDLE    => $S_ACTIVE_REAP,
        $S_ACTIVE_LOAD    => $S_ACTIVE_REAP,
        $S_ACTIVE_REAP    => $S_ACTIVE_REAP,
        $S_ACTIVE_TIMEOUT => $S_ACTIVE_REAP,
        $S_GRACE_IDLE     => $S_GRACE_REAP,
        $S_GRACE_REAP     => $S_GRACE_REAP,
        $S_GRACE_TIMEOUT  => $S_GRACE_REAP,
        $S_SHUTDOWN       => $S_SHUTDOWN,
        $S_FINAL          => $S_FINAL,
    )
);

$BUILDER->define_input(
    $I_ALRM => (
        $S_ACTIVE_RUN     => $S_ACTIVE_TIMEOUT,
        $S_ACTIVE_IDLE    => $S_ACTIVE_TIMEOUT,
        $S_ACTIVE_LOAD    => $S_ACTIVE_TIMEOUT,
        $S_ACTIVE_REAP    => $S_ACTIVE_TIMEOUT,
        $S_ACTIVE_TIMEOUT => $S_ACTIVE_TIMEOUT,
        $S_GRACE_IDLE     => $S_GRACE_TIMEOUT,
        $S_GRACE_REAP     => $S_GRACE_TIMEOUT,
        $S_GRACE_TIMEOUT  => $S_GRACE_TIMEOUT,
        $S_SHUTDOWN       => $S_SHUTDOWN,
        $S_FINAL          => $S_FINAL,
    )
);

$BUILDER->define_input(
    $I_USR2 => (
        $S_ACTIVE_RUN     => $S_ACTIVE_RUN,
        $S_ACTIVE_IDLE    => $S_ACTIVE_RUN,
        $S_ACTIVE_LOAD    => $S_ACTIVE_RUN,
        $S_ACTIVE_REAP    => $S_ACTIVE_RUN,
        $S_ACTIVE_TIMEOUT => $S_ACTIVE_RUN,
        $S_GRACE_IDLE     => $S_GRACE_IDLE,
        $S_GRACE_REAP     => $S_GRACE_IDLE,
        $S_GRACE_TIMEOUT  => $S_GRACE_IDLE,
        $S_SHUTDOWN       => $S_SHUTDOWN,
        $S_FINAL          => $S_FINAL,
    )
);

$BUILDER->define_input(
    $I_HUP => (
        $S_ACTIVE_RUN     => $S_ACTIVE_LOAD,
        $S_ACTIVE_IDLE    => $S_ACTIVE_LOAD,
        $S_ACTIVE_LOAD    => $S_ACTIVE_LOAD,
        $S_ACTIVE_REAP    => $S_ACTIVE_LOAD,
        $S_ACTIVE_TIMEOUT => $S_ACTIVE_LOAD,
        $S_GRACE_IDLE     => $S_GRACE_IDLE,
        $S_GRACE_REAP     => $S_GRACE_IDLE,
        $S_GRACE_TIMEOUT  => $S_GRACE_IDLE,
        $S_SHUTDOWN       => $S_SHUTDOWN,
        $S_FINAL          => $S_FINAL,
    )
);

$BUILDER->define_input(
    $I_TERM => (
        $S_ACTIVE_RUN     => $S_GRACE_IDLE,
        $S_ACTIVE_IDLE    => $S_GRACE_IDLE,
        $S_ACTIVE_LOAD    => $S_GRACE_IDLE,
        $S_ACTIVE_REAP    => $S_GRACE_IDLE,
        $S_ACTIVE_TIMEOUT => $S_GRACE_IDLE,
        $S_GRACE_IDLE     => $S_SHUTDOWN,
        $S_GRACE_REAP     => $S_SHUTDOWN,
        $S_GRACE_TIMEOUT  => $S_SHUTDOWN,
        $S_SHUTDOWN       => $S_FINAL,
        $S_FINAL          => $S_FINAL,
    )
);

$BUILDER->define_input(
    $I_EXIT => (
        $S_ACTIVE_RUN,    => $S_SHUTDOWN,
        $S_ACTIVE_IDLE,   => $S_SHUTDOWN,
        $S_ACTIVE_LOAD    => $S_SHUTDOWN,
        $S_ACTIVE_REAP,   => $S_SHUTDOWN,
        $S_ACTIVE_TIMEOUT => $S_SHUTDOWN,
        $S_GRACE_IDLE     => $S_SHUTDOWN,
        $S_GRACE_REAP     => $S_SHUTDOWN,
        $S_GRACE_TIMEOUT  => $S_SHUTDOWN,
        $S_SHUTDOWN       => $S_FINAL,
        $S_FINAL          => $S_FINAL,
    )
);

sub new {
    my ( $class, %args ) = @_;
    my $config        = delete $args{config};
    my $db            = delete $args{db};
    my $job_source    = delete $args{job_source};
    my $dispatcher    = delete $args{dispatcher};
    my $alarms        = delete $args{alarms};
    my $idler         = delete $args{idler};
    my $initial_state = delete $args{initial_state};
    my $setup_worker  = delete $args{setup_worker};
    my $db_class      = delete $args{db_class};
    !%args or confess 'unrecognized arguments';

    my $self = bless {}, $class;

    $self->{config}       = $config;
    $self->{db}           = $db;
    $self->{job_source}   = $job_source;
    $self->{dispatcher}   = $dispatcher;
    $self->{alarms}       = $alarms;
    $self->{idler}        = $idler;
    $self->{setup_worker} = $setup_worker;
    $self->{db_class}     = $db_class;
    $self->{lifecycle}    = $BUILDER->build(
        initial_state => $initial_state,
        final_states  => [$S_FINAL],
    );

    return $self;
}

sub process {
    my $self  = shift;
    my $input = shift;

    my $state = $self->{lifecycle}->process($input);

    $log->infof( "input(%s) -> state(%s)", $input, $state );

    return $ENTRY_ACTIONS{$state}->($self);
}

sub is_final {
    my $self = shift;

    return $self->{lifecycle}->is_final;
}

sub do_load {
    my $self = shift;

    if ( $self->{config}->load() ) {
        $log->info("config loaded");
        return $I_DONE;
    }
    else {
        $log->warn("config loading failed, keeping old config");
        return ( $self->{config}->is_loaded() ) ? () : $I_EXIT;
    }
}

sub do_run {
    my $self = shift;

    if ( !$self->{dispatcher}->can_spawn_worker ) {
        $log->warn("cannot spawn worker");
        return $I_DONE;
    }

    my $job = $self->{job_source}->claim_job();
    if ( !$job ) {
        $log->infof("no jobs");
        return $I_DONE;
    }

    my $pid = $self->{dispatcher}->spawn(
        $job,
        sub {
            $self->{setup_worker}();
            my $db = $self->{db_class}->connect( config => $self->{config} );
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
        return $I_DONE;
    }

    $log->infof( "job(%s:%s) claimed, worker(%s) spawned",
        $job->item_id, $job->job_id, $pid );
    $self->{alarms}->add_timeout( $self->{config}->timeout() );

    return;
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
    return;
}

sub do_idle {
    my $self = shift;
    $self->{idler}->idle();
    return;
}

sub do_timeout {
    my $self = shift;

    $self->{alarms}->next_timeout();

    my %jobs = $self->{dispatcher}->kill_overdue();

    for my $pid ( keys %jobs ) {
        my $job = $jobs{$pid};
        $log->infof( "overdue worker(%s) killed, releasing job(%s:%s)",
            $pid, $job->item_id, $job->job_id );
        $job->release();
    }

    return;
}

sub do_grace_idle {
    my $self = shift;
    if ( $self->{dispatcher}->has_live_workers ) {
        $self->do_idle;
        return;
    }
    else {
        return $I_DONE;
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
    return $I_DONE;
}

sub do_final {
    return;
}

1;
