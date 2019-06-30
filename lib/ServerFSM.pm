package ServerFSM;
use strict;
use warnings;
use feature 'say';

use Exporter qw( import );
use FSM::Builder;
use Readonly;
use POSIX qw( pause );

our @EXPORT_OK = qw( cmp_inputs %INPUT_PRIORITIES $S_LOAD $S_RUN $S_REAP $S_ALARM $S_IDLE $S_REAP_GRACE $S_WATCH_GRACE $S_IDLE_GRACE $S_SHUTDOWN $S_EXIT $I_ZERO $I_DONE $I_CHLD $I_USR1 $I_ALRM $I_HUP $I_TERM $I_EXIT );

Readonly our $S_LOAD        => 'LOAD';
Readonly our $S_RUN         => 'RUN';
Readonly our $S_IDLE        => 'IDLE';
Readonly our $S_REAP        => 'REAP';
Readonly our $S_ALARM       => 'WATCH';
Readonly our $S_IDLE_GRACE  => 'IDLE_GRACE';
Readonly our $S_REAP_GRACE  => 'REAP_GRACE';
Readonly our $S_WATCH_GRACE => 'WATCH_GRACE';
Readonly our $S_SHUTDOWN    => 'SHUTDOWN';
Readonly our $S_EXIT        => 'EXIT';

Readonly my %ENTRY_ACTIONS => (
    $S_LOAD        => \&do_load,
    $S_RUN         => \&do_run,
    $S_REAP        => \&do_reap,
    $S_ALARM       => \&do_alarm,
    $S_IDLE        => \&do_idle,
    $S_REAP_GRACE  => \&do_reap,
    $S_WATCH_GRACE => \&do_alarm,
    $S_IDLE_GRACE  => \&do_idle_grace,
    $S_SHUTDOWN    => \&do_shutdown,
    $S_EXIT        => \&do_exit,
);

Readonly our $I_DONE => 'done';
Readonly our $I_EXIT => 'exit';
Readonly our $I_TERM => 'term';
Readonly our $I_CHLD => 'chld';
Readonly our $I_HUP  => 'hup';
Readonly our $I_ALRM => 'alrm';
Readonly our $I_USR1 => 'usr1';
Readonly our $I_ZERO => 'zero';

Readonly our %INPUT_PRIORITIES => (
    $I_EXIT => 0,
    $I_DONE => 1,
    $I_TERM => 2,
    $I_CHLD => 3,
    $I_HUP  => 4,
    $I_ALRM => 5,
    $I_USR1 => 6,
    $I_ZERO => 7,
);

Readonly my $BUILDER => FSM::Builder->new();

$BUILDER->define_input(
    $I_ZERO => (
        $S_LOAD        => $S_RUN,
        $S_RUN         => $S_RUN,
        $S_ALARM       => $S_IDLE,
        $S_IDLE        => $S_IDLE,
        $S_REAP        => $S_IDLE,
        $S_WATCH_GRACE => $S_IDLE_GRACE,
        $S_IDLE_GRACE  => $S_IDLE_GRACE,
        $S_REAP_GRACE  => $S_IDLE_GRACE,
        $S_SHUTDOWN    => $S_SHUTDOWN,
        $S_EXIT        => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_DONE => (
        $S_LOAD        => $S_IDLE,
        $S_RUN         => $S_IDLE,
        $S_ALARM       => $S_IDLE,
        $S_IDLE        => $S_IDLE,
        $S_REAP        => $S_IDLE,
        $S_WATCH_GRACE => $S_EXIT,
        $S_IDLE_GRACE  => $S_EXIT,
        $S_REAP_GRACE  => $S_EXIT,
        $S_SHUTDOWN    => $S_EXIT,
        $S_EXIT        => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_CHLD => (
        $S_LOAD        => $S_REAP,
        $S_RUN         => $S_REAP,
        $S_ALARM       => $S_REAP,
        $S_IDLE        => $S_REAP,
        $S_REAP        => $S_REAP,
        $S_WATCH_GRACE => $S_REAP_GRACE,
        $S_IDLE_GRACE  => $S_REAP_GRACE,
        $S_REAP_GRACE  => $S_REAP_GRACE,
        $S_SHUTDOWN    => $S_SHUTDOWN,
        $S_EXIT        => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_ALRM => (
        $S_LOAD        => $S_ALARM,
        $S_RUN         => $S_ALARM,
        $S_ALARM       => $S_ALARM,
        $S_IDLE        => $S_ALARM,
        $S_REAP        => $S_ALARM,
        $S_WATCH_GRACE => $S_WATCH_GRACE,
        $S_IDLE_GRACE  => $S_WATCH_GRACE,
        $S_REAP_GRACE  => $S_WATCH_GRACE,
        $S_SHUTDOWN    => $S_SHUTDOWN,
        $S_EXIT        => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_USR1 => (
        $S_LOAD        => $S_RUN,
        $S_RUN         => $S_RUN,
        $S_ALARM       => $S_RUN,
        $S_IDLE        => $S_RUN,
        $S_REAP        => $S_RUN,
        $S_WATCH_GRACE => $S_IDLE_GRACE,
        $S_IDLE_GRACE  => $S_IDLE_GRACE,
        $S_REAP_GRACE  => $S_IDLE_GRACE,
        $S_SHUTDOWN    => $S_SHUTDOWN,
        $S_EXIT        => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_HUP => (
        $S_LOAD        => $S_LOAD,
        $S_RUN         => $S_LOAD,
        $S_ALARM       => $S_LOAD,
        $S_IDLE        => $S_LOAD,
        $S_REAP        => $S_LOAD,
        $S_WATCH_GRACE => $S_IDLE_GRACE,
        $S_IDLE_GRACE  => $S_IDLE_GRACE,
        $S_REAP_GRACE  => $S_IDLE_GRACE,
        $S_SHUTDOWN    => $S_SHUTDOWN,
        $S_EXIT        => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_TERM => (
        $S_LOAD        => $S_IDLE_GRACE,
        $S_RUN         => $S_IDLE_GRACE,
        $S_ALARM       => $S_IDLE_GRACE,
        $S_IDLE        => $S_IDLE_GRACE,
        $S_REAP        => $S_IDLE_GRACE,
        $S_WATCH_GRACE => $S_SHUTDOWN,
        $S_IDLE_GRACE  => $S_SHUTDOWN,
        $S_REAP_GRACE  => $S_SHUTDOWN,
        $S_SHUTDOWN    => $S_EXIT,
        $S_EXIT        => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_EXIT => (
        $S_LOAD        => $S_SHUTDOWN,
        $S_RUN,        => $S_SHUTDOWN,
        $S_ALARM       => $S_SHUTDOWN,
        $S_IDLE,       => $S_SHUTDOWN,
        $S_REAP,       => $S_SHUTDOWN,
        $S_WATCH_GRACE => $S_SHUTDOWN,
        $S_IDLE_GRACE  => $S_SHUTDOWN,
        $S_REAP_GRACE  => $S_SHUTDOWN,
        $S_SHUTDOWN    => $S_EXIT,
        $S_EXIT        => $S_EXIT,
    )
);

sub cmp_inputs {
    my ( $a, $b ) = @_;
    my $pa = $INPUT_PRIORITIES{$a};
    my $pb = $INPUT_PRIORITIES{$b};
    ( $pa // 1000 ) <=> ( $pb // 1000 )
}

sub new {
    my ( $class, %args ) = @_;
    my $config     = delete $args{config};
    my $allocator  = delete $args{allocator};
    my $dispatcher = delete $args{dispatcher};
    my $alarm      = delete $args{alarm};

    my $self = bless {}, $class;

    $self->{fsm} = $BUILDER->build(
        initial_state   => $S_LOAD,
        final_states    => [ $S_EXIT ],
        output_function => sub {
            my $state = shift;
            my $input = shift;

            say "Input: " . $input;
            say "State: " . $state;

            return $ENTRY_ACTIONS{$state}->( $self );
        },
    );
    $self->{config}     = $config;
    $self->{allocator}  = $allocator;
    $self->{dispatcher} = $dispatcher;
    $self->{alarm}      = $alarm;

    return $self;
}

sub process {
    my $self  = shift;
    my $input = shift;

    return $self->{fsm}->process( $input, $self );
}

sub is_alive {
    my $self  = shift;

    return !$self->{fsm}->is_final;
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

    my $id = $self->{allocator}->claim();
    if ( !defined $id ) {
        say "No jobs available";
        return $I_DONE;
    }

    say "Claimed job $id";

    my $pid = $self->{dispatcher}->dispatch( $id );
    if ( $pid ) {
        say "Dispatched job $id to process $pid";
        $self->{alarm}->insert( $self->{config}->timeout(), $pid );
    }
    else {
        say "Failed to dispatch job $id";
        $self->{allocator}->release( $id );
    }

    return ();
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
    pause;
    return;
}

sub do_alarm {
    my $self = shift;
    my $pid = $self->{alarm}->extract_earliest();
    if ( $pid ) {
        my $jid = $self->{dispatcher}->kill( $pid );
        if ( $jid ) {
            say "Killed pid $pid, releasing job $jid";
            $self->{allocator}->release( $jid );
        }
    }
    return;
}

sub do_idle_grace {
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
