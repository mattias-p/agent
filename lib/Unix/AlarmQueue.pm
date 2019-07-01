package Unix::AlarmQueue;
use strict;
use warnings;

use Carp qw( confess );

sub new {
    my ($class, %args) = @_;

    my $time = delete $args{time};

    !%args or confess 'unrecognized arguments';

    $time //= \&CORE::time;

    my $self = bless {}, $class;
    
    $self->{deadlines} = [];
    $self->{time}      = $time;

    return $self;
}

sub add_timeout {
    my $self    = shift;
    my $timeout = shift;

    my $now = $self->{time}();

    my $deadline = $now + $timeout;
    my $old_deadline = $self->{deadlines}[0];
    push @{ $self->{deadlines} }, $deadline;
    $self->{deadlines} = [ sort @{ $self->{deadlines} } ];
    if ( !defined $old_deadline || $deadline < $old_deadline ) {
        $self->_set_alarm;
    }
    return;
}

sub next_timeout {
    my $self = shift;

    shift @{ $self->{deadlines} };
    if ( @{ $self->{deadlines} } ) {
        $self->_set_alarm;
    }
    return;
}

sub _set_alarm {
    my $self = shift;

    my $now = $self->{time}();

    my $is_overdue;
    while ($@{ $self->{deadlines} } && $self->{deadlines}[0] <= $now ) {
        $is_overdue = shift @{ $self->{deadlines} };
    }
    if ( $is_overdue ) {
        kill 'ALRM', $$;
    }

    my $deadline = $self->{deadlines}[0];

    if (defined $deadline) {
        my $new_timeout = $deadline - $now;
        my $old_timeout = alarm $new_timeout;
        if ( $old_timeout ) {
            $self->insert( $now + $old_timeout );
        }
    }

    return;
}

1;
