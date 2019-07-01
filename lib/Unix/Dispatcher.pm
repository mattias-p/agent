package Unix::Dispatcher;
use strict;
use warnings;

use Carp qw( confess );
use Config;
use Heap::Binary;
use Log::Any qw( $log );
use POSIX ":sys_wait_h";
use Readonly;

Readonly my @SIG_NAMES => ( split ' ', $Config{sig_name} );

sub new {
    my ( $class, %args ) = @_;

    my $config = delete $args{config};
    my $action = delete $args{action};
    my $p_fail = delete $args{p_fail};

    !%args or confess 'unexpected arguments';

    $p_fail //= 0.0;

    my $self = bless {}, $class;

    $self->{jobs}   = {};
    $self->{action} = $action;
    $self->{p_fail} = $p_fail;
    $self->{config} = $config;

    return $self;
}

sub jobs {
    my $self = shift;

    return values %{ $self->{jobs} };
}

sub can_spawn_worker {
    my $self = shift;

    return scalar keys %{ $self->{jobs} } < $self->{config}->max_workers;
}

sub spawn {
    my $self   = shift;
    my $jid    = shift;
    my $finish = shift;

    if ($self->{p_fail} > 0 && rand() < $self->{p_fail} ) {
        $log->warn("injected failure (dispatcher)");
        return;
    }

    my $pid = fork;
    if ( !defined $pid ) {
        return;
    }
    if ( $pid == 0 ) {
        $self->{action}($jid);
        $finish->();
        exit 0;
    }
    $self->{jobs}{$pid} = $jid;

    return $pid;
}

sub _reap {
    my $self  = shift;
    my $flags = shift;

    my %reaped;

    for my $pid ( keys %{ $self->{jobs} } ) {
        my $status = waitpid( $pid, $flags );
        if ( $status != 0 ) {
            my $jid = delete $self->{jobs}{$pid};
            my $severity = $self->termination_severity( ${^CHILD_ERROR_NATIVE} );
            $reaped{$pid} = [ $jid, $severity, ${^CHILD_ERROR_NATIVE} ];
        }
    }

    return %reaped;
}

sub reap {
    my $self = shift;
    return $self->_reap( WNOHANG );
}

sub kill {
    my $self = shift;
    my $pid  = shift;

    my $jid = $self->{jobs}{$pid};

    if ( $jid ) {
        kill 'KILL', $pid;
        return $jid;
    }
    else {
        return;
    }
}

sub shutdown {
    my $self = shift;

    for my $pid ( keys %{ $self->{jobs} } ) {
        CORE::kill 'KILL', $pid;
    }

    return $self->_reap( 0 );
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
