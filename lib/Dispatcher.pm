package Dispatcher;
use strict;
use warnings;

use Carp qw( confess );
use Heap::Binary;
use POSIX ":sys_wait_h";

sub new {
    my ( $class, %args ) = @_;

    my $action = delete $args{action};
    my $p_fail = delete $args{p_fail};

    !%args or confess 'unexpected arguments';

    $p_fail //= 0.0;

    my $self = bless {}, $class;

    $self->{jobs}   = {};
    $self->{action} = $action;
    $self->{p_fail} = $p_fail;

    return $self;
}

sub jobs {
    my $self = shift;

    return values %{ $self->{jobs} };
}

sub dispatch {
    my $self   = shift;
    my $jid    = shift;
    my $finish = shift;

    if ($self->{p_fail} > 0 && rand() < $self->{p_fail} ) {
        warn "injected failure";
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
            $reaped{$pid} = [ $jid, ${^CHILD_ERROR_NATIVE} ];
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

1;
