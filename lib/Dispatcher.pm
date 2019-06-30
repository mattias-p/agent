package Dispatcher;
use strict;
use warnings;

use Heap::Binary;
use POSIX ":sys_wait_h";
use Signal qw( uninstall_handlers );

sub new {
    my $class = shift;

    my $self = bless {}, $class;

    $self->{jobs} = {};

    return $self;
}

sub jobs {
    my $self = shift;

    return values %{ $self->{jobs} };
}

sub dispatch {
    my $self = shift;
    my $jid  = shift;

    if ( rand() < 0.75 ) {
        my $pid = fork;
        if ( !defined $pid ) {
            return;
        }
        if ( $pid == 0 ) {
            uninstall_handlers();
            sleep( 5 + rand 11 );
            exit 0;
        }
        $self->{jobs}{$pid} = $jid;

        return $pid;
    }
    else {
        return;
    }
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
