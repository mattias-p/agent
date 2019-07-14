package Unix::TaskManager;
use strict;
use warnings;

use Carp qw( confess );
use Log::Any qw( $log );
use POSIX ":sys_wait_h";
use Unix::WaitStatus;

sub new {
    my ( $class, %args ) = @_;
    my $alarms  = delete $args{alarms};
    my $signals = delete $args{signals};
    my $p_fail  = delete $args{p_fail};
    !%args or confess 'unexpected arguments';

    $p_fail //= 0.0;
    my $has_overdue    = 0;
    my $has_terminated = 0;
    my $jobs           = {};

    my $self = bless {}, $class;

    $self->{alarms}         = $alarms;
    $self->{has_overdue}    = $has_overdue;
    $self->{has_terminated} = $has_terminated;
    $self->{jobs}           = $jobs;
    $self->{p_fail}         = $p_fail;
    $self->{signals}        = $signals;

    return $self;
}

sub active_task_count {
    my $self = shift;

    return scalar keys %{ $self->{jobs} };
}

sub poll {
    my $self = shift;

    $self->{has_terminated} ||= $self->{signals}->was_caught('CHLD');
    $self->{has_overdue}    ||= $self->{signals}->was_caught('ALRM');

    return;
}

sub has_terminated_tasks {
    my $self = shift;

    return $self->{has_terminated};
}

sub has_overdue_tasks {
    my $self = shift;

    return $self->{has_overdue};
}

sub add_task {
    my $self    = shift;
    my $timeout = shift;
    my $data    = shift;
    my $action  = shift;

    if ($self->{p_fail} > 0 && rand() < $self->{p_fail} ) {
        $log->warn("injected failure (dispatcher)");
        return;
    }

    my $now = time();
    my $pid = fork;
    if ( !defined $pid ) {
        return;
    }
    if ( $pid == 0 ) {
        my $exitstatus = $action->();
        exit( $exitstatus // 2 );
    }

    my $deadline = $now + $timeout;
    $self->{jobs}{$pid} = [ $deadline, $data ];
    $self->{alarms}->add_alarm( $deadline, $now );

    return $pid;
}

sub reap_terminated_tasks {
    my $self  = shift;

    my %reaped;
    for my $pid ( keys %{ $self->{jobs} } ) {
        my $status = waitpid( $pid, WNOHANG );
        if ( $status != 0 ) {
            my ( undef, $data ) = @{ delete $self->{jobs}{$pid} };
            my $wait_status = Unix::WaitStatus->new( ${^CHILD_ERROR_NATIVE} );
            $reaped{$pid} = [ $wait_status, $data ];
        }
    }

    $self->{has_terminated} = 0;

    return %reaped;
}

sub terminate_tasks {
    my ( $self, %args ) = @_;
    my $treshold = delete $args{treshold};
    !%args
      or confess 'unrecognized arguments';

    if ( defined $treshold ) {
        $self->{alarms}->refresh_alarm($treshold);
    }

    my %jobs;
    for my $pid ( keys %{ $self->{jobs} } ) {
        if ( !defined $treshold || $self->{jobs}{$pid}[0] <= $treshold )
        {
            kill 'KILL', $pid;
            my $data = $self->{jobs}{$pid}[1];
            $jobs{$pid} = $data;
        }
    }

    $self->{has_overdue} = 0;

    return %jobs;
}

1;
