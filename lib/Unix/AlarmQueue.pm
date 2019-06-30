package Unix::AlarmQueue;
use strict;
use warnings;

use Heap::Binary;

sub new {
    my $class = shift;

    my $self = bless {}, $class;
    
    $self->{timeouts} = Heap::Binary->new( sub { $_[0][0] <=> $_[1][0] } );

    return $self;
}

sub insert {
    my $self    = shift;
    my $timeout = shift;
    my $data    = shift;

    $self->{timeouts}->insert( [time() + $timeout, $data] );
    $self->_update;

    return;
}

sub extract_earliest {
    my $self = shift;

    my $item = $self->{timeouts}->extract_min();
    if ( $item ) {
        $self->_update;
        return $item->[1];
    }
    else {
        return;
    }
}

sub _update {
    my $self = shift;

    my $item = $self->{timeouts}->find_min();

    return if !$item;

    my $timeout = $item->[0] - time();

    if ( $timeout <= 0 ) {
        $timeout = 0;
        kill 'ALRM', $$;
    }

    alarm $timeout;

    return;
}

1;
