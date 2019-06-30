package App::Server;
use strict;
use warnings;
use feature 'say';

use Carp qw( confess );
use Exporter qw( import );
use FSM::Builder;
use Readonly;

use base 'FSM';

our @EXPORT_OK = qw( cmp_inputs $S_LOAD $S_RUN $S_REAP $S_TIMEOUT $S_IDLE $S_GRACE_REAP $S_GRACE_TIMEOUT $S_GRACE_IDLE $S_SHUTDOWN $S_EXIT $I_IDLE $I_DONE $I_REAP $I_WORK $I_TIMEOUT $I_LOAD $I_TERM $I_EXIT );

Readonly our $S_LOAD          => 'LOAD';
Readonly our $S_RUN           => 'RUN';
Readonly our $S_IDLE          => 'IDLE';
Readonly our $S_REAP          => 'REAP';
Readonly our $S_TIMEOUT       => 'TIMEOUT';
Readonly our $S_GRACE_IDLE    => 'GRACE_IDLE';
Readonly our $S_GRACE_REAP    => 'GRACE_REAP';
Readonly our $S_GRACE_TIMEOUT => 'GRACE_TIMEOUT';
Readonly our $S_SHUTDOWN      => 'SHUTDOWN';
Readonly our $S_EXIT          => 'EXIT';

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
    $S_EXIT          => \&do_exit,
);

Readonly our $I_EXIT    => 'exit';
Readonly our $I_DONE    => 'done';
Readonly our $I_TERM    => 'term';
Readonly our $I_REAP    => 'reap';
Readonly our $I_LOAD    => 'load';
Readonly our $I_TIMEOUT => 'timeout';
Readonly our $I_WORK    => 'work';
Readonly our $I_IDLE    => 'idle';

Readonly our %INPUT_PRIORITIES => (
    $I_EXIT    => 0,
    $I_DONE    => 1,
    $I_TERM    => 2,
    $I_REAP    => 3,
    $I_LOAD    => 4,
    $I_TIMEOUT => 5,
    $I_WORK    => 6,
    $I_IDLE    => 7,
);

Readonly my $BUILDER => FSM::Builder->new();

$BUILDER->define_input(
    $I_IDLE => (
        $S_LOAD          => $S_RUN,
        $S_RUN           => $S_RUN,
        $S_TIMEOUT       => $S_IDLE,
        $S_IDLE          => $S_IDLE,
        $S_REAP          => $S_IDLE,
        $S_GRACE_TIMEOUT => $S_GRACE_IDLE,
        $S_GRACE_IDLE    => $S_GRACE_IDLE,
        $S_GRACE_REAP    => $S_GRACE_IDLE,
        $S_SHUTDOWN      => $S_SHUTDOWN,
        $S_EXIT          => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_DONE => (
        $S_LOAD          => $S_IDLE,
        $S_RUN           => $S_IDLE,
        $S_TIMEOUT       => $S_IDLE,
        $S_IDLE          => $S_IDLE,
        $S_REAP          => $S_IDLE,
        $S_GRACE_TIMEOUT => $S_EXIT,
        $S_GRACE_IDLE    => $S_EXIT,
        $S_GRACE_REAP    => $S_EXIT,
        $S_SHUTDOWN      => $S_EXIT,
        $S_EXIT          => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_REAP => (
        $S_LOAD          => $S_REAP,
        $S_RUN           => $S_REAP,
        $S_TIMEOUT       => $S_REAP,
        $S_IDLE          => $S_REAP,
        $S_REAP          => $S_REAP,
        $S_GRACE_TIMEOUT => $S_GRACE_REAP,
        $S_GRACE_IDLE    => $S_GRACE_REAP,
        $S_GRACE_REAP    => $S_GRACE_REAP,
        $S_SHUTDOWN      => $S_SHUTDOWN,
        $S_EXIT          => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_TIMEOUT => (
        $S_LOAD          => $S_TIMEOUT,
        $S_RUN           => $S_TIMEOUT,
        $S_TIMEOUT       => $S_TIMEOUT,
        $S_IDLE          => $S_TIMEOUT,
        $S_REAP          => $S_TIMEOUT,
        $S_GRACE_TIMEOUT => $S_GRACE_TIMEOUT,
        $S_GRACE_IDLE    => $S_GRACE_TIMEOUT,
        $S_GRACE_REAP    => $S_GRACE_TIMEOUT,
        $S_SHUTDOWN      => $S_SHUTDOWN,
        $S_EXIT          => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_WORK => (
        $S_LOAD          => $S_RUN,
        $S_RUN           => $S_RUN,
        $S_TIMEOUT       => $S_RUN,
        $S_IDLE          => $S_RUN,
        $S_REAP          => $S_RUN,
        $S_GRACE_TIMEOUT => $S_GRACE_IDLE,
        $S_GRACE_IDLE    => $S_GRACE_IDLE,
        $S_GRACE_REAP    => $S_GRACE_IDLE,
        $S_SHUTDOWN      => $S_SHUTDOWN,
        $S_EXIT          => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_LOAD => (
        $S_LOAD          => $S_LOAD,
        $S_RUN           => $S_LOAD,
        $S_TIMEOUT       => $S_LOAD,
        $S_IDLE          => $S_LOAD,
        $S_REAP          => $S_LOAD,
        $S_GRACE_TIMEOUT => $S_GRACE_IDLE,
        $S_GRACE_IDLE    => $S_GRACE_IDLE,
        $S_GRACE_REAP    => $S_GRACE_IDLE,
        $S_SHUTDOWN      => $S_SHUTDOWN,
        $S_EXIT          => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_TERM => (
        $S_LOAD          => $S_GRACE_IDLE,
        $S_RUN           => $S_GRACE_IDLE,
        $S_TIMEOUT       => $S_GRACE_IDLE,
        $S_IDLE          => $S_GRACE_IDLE,
        $S_REAP          => $S_GRACE_IDLE,
        $S_GRACE_TIMEOUT => $S_SHUTDOWN,
        $S_GRACE_IDLE    => $S_SHUTDOWN,
        $S_GRACE_REAP    => $S_SHUTDOWN,
        $S_SHUTDOWN      => $S_EXIT,
        $S_EXIT          => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_EXIT => (
        $S_LOAD          => $S_SHUTDOWN,
        $S_RUN,          => $S_SHUTDOWN,
        $S_TIMEOUT       => $S_SHUTDOWN,
        $S_IDLE,         => $S_SHUTDOWN,
        $S_REAP,         => $S_SHUTDOWN,
        $S_GRACE_TIMEOUT => $S_SHUTDOWN,
        $S_GRACE_IDLE    => $S_SHUTDOWN,
        $S_GRACE_REAP    => $S_SHUTDOWN,
        $S_SHUTDOWN      => $S_EXIT,
        $S_EXIT          => $S_EXIT,
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
    my $allocator  = delete $args{allocator};
    my $dispatcher = delete $args{dispatcher};
    my $alarms     = delete $args{alarms};
    my $idler      = delete $args{idler};

    my $self;
    $self = $BUILDER->build(
        initial_state   => $S_LOAD,
        final_states    => [ $S_EXIT ],
        output_function => sub {
            my $state = shift;
            my $input = shift;

            say "Input($input) -> State($state)";

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
        say "Successfully loaded config";
        return $I_DONE;
    }
    else {
        say "Failed to load config";
        return ( $self->{config}->is_loaded() ) ? () : $I_EXIT;
    }
}

sub do_run {
    my $self = shift;

    my $jid = $self->{allocator}->claim();
    return $I_DONE if !defined $jid;

    my $pid = $self->{dispatcher}->dispatch( $jid, sub {
        say "Releasing job $jid after completion";
        $self->{allocator}->release( $jid );
    });
    if ( $pid ) {
        say "Dispatched job $jid to process $pid";
        $self->{alarms}->insert( $self->{config}->timeout(), $pid );
    }
    else {
        say "Failed to dispatch job $jid, releasing it again";
        $self->{allocator}->release( $jid );
    }

    return;
}

sub do_reap {
    my $self = shift;
    my %jobs = $self->{dispatcher}->reap();
    for my $pid ( keys %jobs ) {
        my ( $jid, $status ) = @{ $jobs{$pid} };
        say "Reaped pid $pid (status $status), releasing job $jid";
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
            say "Killed pid $pid, releasing job $jid";
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
        my ( $jid, $status ) = @{ $jobs{$pid} };
        say "Reaped pid $pid (status $status)";
        say "Releasing job $jid";
        $self->{allocator}->release( $jid );
    }
    return $I_DONE;
}

sub do_exit {
    return;
}

1;
