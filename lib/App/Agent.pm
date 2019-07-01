package App::Agent;
use strict;
use warnings;

use Carp qw( confess );
use Exporter qw( import );
use FSM::Builder;
use Log::Any qw( $log );
use Readonly;

use base 'FSM';

our @EXPORT_OK = qw( cmp_inputs $S_LOAD $S_RUN $S_REAP $S_TIMEOUT $S_IDLE $S_GRACE_REAP $S_GRACE_TIMEOUT $S_GRACE_IDLE $S_SHUTDOWN $S_FINAL $I_STEP $I_DONE $I_CHLD $I_USR2 $I_ALRM $I_HUP $I_TERM $I_EXIT );

Readonly our $S_LOAD          => 'LOAD';
Readonly our $S_RUN           => 'RUN';
Readonly our $S_IDLE          => 'IDLE';
Readonly our $S_REAP          => 'REAP';
Readonly our $S_TIMEOUT       => 'TIMEOUT';
Readonly our $S_GRACE_IDLE    => 'GRACE_IDLE';
Readonly our $S_GRACE_REAP    => 'GRACE_REAP';
Readonly our $S_GRACE_TIMEOUT => 'GRACE_TIMEOUT';
Readonly our $S_SHUTDOWN      => 'SHUTDOWN';
Readonly our $S_FINAL         => 'EXIT';

Readonly my %ENTRY_ACTIONS => (
    $S_LOAD          => \&do_load,
    $S_RUN           => \&do_run,
    $S_REAP          => \&do_reap,
    $S_TIMEOUT       => \&do_timeout,
    $S_IDLE          => \&do_idle,
    $S_GRACE_REAP    => \&do_reap,
    $S_GRACE_TIMEOUT => \&do_timeout,
    $S_GRACE_IDLE    => \&do_grace_idle,
    $S_SHUTDOWN      => \&do_shutdown,
    $S_FINAL         => \&do_final,
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

Readonly my $BUILDER => FSM::Builder->new();

$BUILDER->define_input(
    $I_STEP => (
        $S_RUN           => $S_RUN,
        $S_IDLE          => $S_RUN,
        $S_LOAD          => $S_RUN,
        $S_REAP          => $S_RUN,
        $S_TIMEOUT       => $S_RUN,
        $S_GRACE_IDLE    => $S_GRACE_IDLE,
        $S_GRACE_REAP    => $S_GRACE_IDLE,
        $S_GRACE_TIMEOUT => $S_GRACE_IDLE,
        $S_SHUTDOWN      => $S_SHUTDOWN,
        $S_FINAL         => $S_FINAL,
    )
);

$BUILDER->define_input(
    $I_DONE => (
        $S_RUN           => $S_IDLE,
        $S_IDLE          => $S_RUN,
        $S_LOAD          => $S_RUN,
        $S_REAP          => $S_RUN,
        $S_TIMEOUT       => $S_RUN,
        $S_GRACE_IDLE    => $S_FINAL,
        $S_GRACE_REAP    => $S_FINAL,
        $S_GRACE_TIMEOUT => $S_FINAL,
        $S_SHUTDOWN      => $S_FINAL,
        $S_FINAL         => $S_FINAL,
    )
);

$BUILDER->define_input(
    $I_CHLD => (
        $S_RUN           => $S_REAP,
        $S_IDLE          => $S_REAP,
        $S_LOAD          => $S_REAP,
        $S_REAP          => $S_REAP,
        $S_TIMEOUT       => $S_REAP,
        $S_GRACE_IDLE    => $S_GRACE_REAP,
        $S_GRACE_REAP    => $S_GRACE_REAP,
        $S_GRACE_TIMEOUT => $S_GRACE_REAP,
        $S_SHUTDOWN      => $S_SHUTDOWN,
        $S_FINAL         => $S_FINAL,
    )
);

$BUILDER->define_input(
    $I_ALRM => (
        $S_RUN           => $S_TIMEOUT,
        $S_IDLE          => $S_TIMEOUT,
        $S_LOAD          => $S_TIMEOUT,
        $S_REAP          => $S_TIMEOUT,
        $S_TIMEOUT       => $S_TIMEOUT,
        $S_GRACE_IDLE    => $S_GRACE_TIMEOUT,
        $S_GRACE_REAP    => $S_GRACE_TIMEOUT,
        $S_GRACE_TIMEOUT => $S_GRACE_TIMEOUT,
        $S_SHUTDOWN      => $S_SHUTDOWN,
        $S_FINAL         => $S_FINAL,
    )
);

$BUILDER->define_input(
    $I_USR2 => (
        $S_RUN           => $S_RUN,
        $S_IDLE          => $S_RUN,
        $S_LOAD          => $S_RUN,
        $S_REAP          => $S_RUN,
        $S_TIMEOUT       => $S_RUN,
        $S_GRACE_IDLE    => $S_GRACE_IDLE,
        $S_GRACE_REAP    => $S_GRACE_IDLE,
        $S_GRACE_TIMEOUT => $S_GRACE_IDLE,
        $S_SHUTDOWN      => $S_SHUTDOWN,
        $S_FINAL         => $S_FINAL,
    )
);

$BUILDER->define_input(
    $I_HUP => (
        $S_RUN           => $S_LOAD,
        $S_IDLE          => $S_LOAD,
        $S_LOAD          => $S_LOAD,
        $S_REAP          => $S_LOAD,
        $S_TIMEOUT       => $S_LOAD,
        $S_GRACE_IDLE    => $S_GRACE_IDLE,
        $S_GRACE_REAP    => $S_GRACE_IDLE,
        $S_GRACE_TIMEOUT => $S_GRACE_IDLE,
        $S_SHUTDOWN      => $S_SHUTDOWN,
        $S_FINAL         => $S_FINAL,
    )
);

$BUILDER->define_input(
    $I_TERM => (
        $S_RUN           => $S_GRACE_IDLE,
        $S_IDLE          => $S_GRACE_IDLE,
        $S_LOAD          => $S_GRACE_IDLE,
        $S_REAP          => $S_GRACE_IDLE,
        $S_TIMEOUT       => $S_GRACE_IDLE,
        $S_GRACE_IDLE    => $S_SHUTDOWN,
        $S_GRACE_REAP    => $S_SHUTDOWN,
        $S_GRACE_TIMEOUT => $S_SHUTDOWN,
        $S_SHUTDOWN      => $S_FINAL,
        $S_FINAL         => $S_FINAL,
    )
);

$BUILDER->define_input(
    $I_EXIT => (
        $S_RUN,          => $S_SHUTDOWN,
        $S_IDLE,         => $S_SHUTDOWN,
        $S_LOAD          => $S_SHUTDOWN,
        $S_REAP,         => $S_SHUTDOWN,
        $S_TIMEOUT       => $S_SHUTDOWN,
        $S_GRACE_IDLE    => $S_SHUTDOWN,
        $S_GRACE_REAP    => $S_SHUTDOWN,
        $S_GRACE_TIMEOUT => $S_SHUTDOWN,
        $S_SHUTDOWN      => $S_FINAL,
        $S_FINAL         => $S_FINAL,
    )
);

sub cmp_inputs {
    my ( $a, $b ) = @_;

    ( exists $INPUT_PRIORITIES{$a} && exists $INPUT_PRIORITIES{$b} )
      or confess 'unrecognized inputs';

    return $INPUT_PRIORITIES{$a} <=> $INPUT_PRIORITIES{$b};
}

sub new {
    my ( $class, %args ) = @_;
    my $config     = delete $args{config};
    my $allocator     = delete $args{allocator};
    my $dispatcher    = delete $args{dispatcher};
    my $alarms        = delete $args{alarms};
    my $idler         = delete $args{idler};
    my $initial_state = delete $args{initial_state};
    !%args or confess 'unrecognized arguments';

    my $self;
    $self = $BUILDER->build(
        class           => $class,
        initial_state   => $initial_state,
        final_states    => [ $S_FINAL ],
        output_function => sub {
            my $state = shift;
            my $input = shift;

            $log->infof( "Input(%s) -> State(%s)", $input, $state );

            return $ENTRY_ACTIONS{$state}->( $self );
        },
    );
    $self->{config}     = $config;
    $self->{allocator}  = $allocator;
    $self->{dispatcher} = $dispatcher;
    $self->{alarms}     = $alarms;
    $self->{idler}      = $idler;

    return $self;
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

    if ( !$self->{dispatcher}->can_dispatch_worker ) {
        $log->warn("cannot spawn worker");
        return $I_DONE;
    }

    my $jid = $self->{allocator}->claim();
    if ( !$jid ) {
        $log->infof( "no jobs" );
        return $I_DONE;
    }

    my $pid = $self->{dispatcher}->spawn( $jid, sub {
        $log->infof( "job(%s) completed, releasing it", $jid );
        $self->{allocator}->release( $jid );
    });
    if ( !$pid ) {
        $log->infof( "job(%s) spawning worker failed, releasing job", $jid );
        $self->{allocator}->release( $jid );
        return $I_DONE;
    }

    $log->infof( "job(%s) allocated, worker(%s) spawned", $jid, $pid );
    $self->{alarms}->insert( $self->{config}->timeout(), $pid );

    return;
}

sub do_reap {
    my $self = shift;
    my %jobs = $self->{dispatcher}->reap();
    for my $pid ( keys %jobs ) {
        my ( $jid, $severity, $details ) = @{ $jobs{$pid} };
        my $is_severity = "is_$severity";
        if ( $log->$is_severity() ) {
            my $reason = $self->{dispatcher}->termination_reason($details);
            $log->$severity( "worker($pid) $reason, releasing job($jid)" );
        }
        $self->{allocator}->release( $jid );
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
    my $pid = $self->{alarms}->extract_earliest();
    if ( $pid ) {
        my $jid = $self->{dispatcher}->kill( $pid );
        if ( $jid ) {
            $log->infof( "worker(%s) killed, releasing job(%s)", $pid, $jid );
            $self->{allocator}->release( $jid );
        }
    }
    return;
}

sub do_grace_idle {
    my $self = shift;
    if ( $self->{dispatcher}->jobs ) {
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
        my ( $jid, $severity, $details ) = @{ $jobs{$pid} };
        my $is_severity = "is_$severity";
        if ( $log->$is_severity() ) {
            my $reason = $self->{dispatcher}->termination_reason($details);
            $log->$severity( "worker($pid) $reason, releasing job($jid)" );
        }
        $self->{allocator}->release( $jid );
    }
    return $I_DONE;
}

sub do_final {
    return;
}

1;
