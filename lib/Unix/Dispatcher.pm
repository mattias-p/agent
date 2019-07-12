package Unix::Dispatcher;
use strict;
use warnings;

use Carp qw( confess );
use Config;
use Log::Any qw( $log );
use POSIX ":sys_wait_h";
use Readonly;

Readonly my @SIG_NAMES => ( split ' ', $Config{sig_name} );

sub new {
    my ( $class, %args ) = @_;

    my $max_workers = delete $args{max_workers};
    my $p_fail      = delete $args{p_fail};
    my $timeout     = delete $args{timeout};

    !%args or confess 'unexpected arguments';

    $p_fail //= 0.0;
    my $jobs = {};

    my $self = bless {}, $class;

    $self->{jobs}        = $jobs;
    $self->{max_workers} = $max_workers;
    $self->{p_fail}      = $p_fail;
    $self->{timeout}     = $timeout;

    return $self;
}

sub set_max_workers {
    my $self  = shift;
    my $value = shift;

    $self->{max_workers} = $value;

    return;
}

sub set_timeout {
    my $self  = shift;
    my $value = shift;

    $self->{timeout} = $value;

    return;
}

sub get_timeout {
    my $self = shift;

    return $self->{timeout};
}

sub has_live_workers {
    my $self = shift;

    return !!%{ $self->{jobs} };
}

sub has_available_worker {
    my $self = shift;

    return scalar keys %{ $self->{jobs} } < $self->{max_workers};
}

sub spawn {
    my $self   = shift;
    my $data   = shift;
    my $action = shift;

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
    my $deadline = $now + $self->{timeout};
    $self->{jobs}{$pid} = [ $deadline, $data ];

    return $pid;
}

sub reap {
    my $self  = shift;

    my %reaped;
    for my $pid ( keys %{ $self->{jobs} } ) {
        my $status = waitpid( $pid, WNOHANG );
        if ( $status != 0 ) {
            my ( undef, $data ) = @{ delete $self->{jobs}{$pid} };
            my $severity = $self->termination_severity( ${^CHILD_ERROR_NATIVE} );
            $reaped{$pid} = [ $severity, ${^CHILD_ERROR_NATIVE}, $data ];
        }
    }

    return %reaped;
}

sub kill_workers {
    my ( $self, %args ) = @_;
    my $treshold = delete $args{treshold};
    !%args
      or confess 'unrecognized arguments';

    my %jobs;
    for my $pid ( keys %{ $self->{jobs} } ) {
        if ( !defined $treshold || $self->{jobs}{$pid}[0] <= $treshold )
        {
            kill 'KILL', $pid;
            my $data = $self->{jobs}{$pid}[1];
            $jobs{$pid} = $data;
        }
    }

    return %jobs;
}

sub termination_severity {
    my ( $self, $child_error_native ) = @_;

    if ( $child_error_native < 0 ) {
        return "error";
    }
    elsif ( WIFEXITED( $child_error_native ) ) {
        if ( WEXITSTATUS($child_error_native) == 0 ) {
            return "info";
        }
        else {
            return "warn";
        }
    }
    elsif ( WIFSIGNALED( $child_error_native ) ) {
        return "warn";
    }
    elsif ( WIFSTOPPED( $child_error_native ) ) {
        return "notice";
    }
    else {
        return "warn";
    }
}

sub termination_reason {
    my ( $self, $child_error_native ) = @_;

    if ( $child_error_native < 0 ) {
        return "does not exist";
    }
    elsif ( WIFEXITED( $child_error_native ) ) {
        my $exit_status = WEXITSTATUS($child_error_native);
        if ( $exit_status == 0 ) {
            return sprintf "terminated successfully";
        }
        else {
            return sprintf "terminated normally with exit status $exit_status";
        }
    }
    elsif ( WIFSIGNALED( $child_error_native ) ) {
        my $sig_num = WTERMSIG($child_error_native);
        my $signal =
          ( $sig_num <= $#SIG_NAMES )
          ? "$sig_num (SIG" . $SIG_NAMES[$sig_num] . ")"
          : $sig_num;
        return sprintf "terminated due to uncaught signal $signal";
    }
    elsif ( WIFSTOPPED( $child_error_native ) ) {
        my $sig_num = WSTOPSIG($child_error_native);
        my $signal =
          ( $sig_num <= $#SIG_NAMES )
          ? "$sig_num (SIG" . $SIG_NAMES[$sig_num] . ")"
          : $sig_num;
        return sprintf "stopped by signal $signal";
    }
    else {
        return "in unknown state $child_error_native";
    }
}

1;
