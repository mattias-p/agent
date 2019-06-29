package Dispatcher;
use strict;
use warnings;

use POSIX ":sys_wait_h";
use Signal qw( uninstall_handlers );

sub new {
    my $class = shift;

    my $self = bless {}, $class;

    $self->{jobs} = {};

    return $self;
}

sub dispatch {
    my $self = shift;
    my $jid   = shift;

    if ( rand() < 0.5 ) {
        my $pid = fork;
        if (!defined $pid) {
            return;
        }
        if ( $pid == 0 ) {
            uninstall_handlers();
            sleep 10;
            exit 0;
        }
        $self->{jobs}{$pid} = $jid;

        return $pid;
    }
    else {
        return;
    }
}


sub reap {
    my $self = shift;

    my %reaped;

    for my $pid ( keys %{ $self->{jobs} } ) {
        my $status = waitpid( $pid, WNOHANG );
        if ( $status != 0 ) {
            my $jid = delete $self->{jobs}{$pid};
            $reaped{$pid} = [ $jid, $status ];
        }
    }

    return %reaped;
}

1;
