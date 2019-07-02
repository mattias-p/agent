package Unix::AlarmQueue;
use strict;
use warnings;

use Carp qw( confess );
use Log::Any qw( $log );

sub new {
    my ($class, %args) = @_;
    !%args or confess 'unrecognized arguments';

    my $self = bless {}, $class;
    
    $self->{deadlines} = [];

    return $self;
}

sub add_timeout {
    my $self    = shift;
    my $timeout = shift;

    my $now      = time;
    my $deadline = $now + $timeout;
    $log->debugf( "adding deadline(@%d) i.e. now+%ds", $deadline, $timeout );

    my $old_deadline = $self->{deadlines}[0];
    push @{ $self->{deadlines} }, $deadline;
    $self->{deadlines} = [ sort @{ $self->{deadlines} } ];
    if ( !defined $old_deadline || $deadline < $old_deadline ) {
        $self->next_timeout();
    }
    return;
}

sub next_timeout {
    my $self = shift;

    my $now      = time;
    my $deadline = $self->{deadlines}[0];
    while ( defined $deadline && $deadline <= $now ) {
        $log->debugf( "removing deadline(@%d)", $deadline );
        shift @{ $self->{deadlines} };
        $deadline = $self->{deadlines}[0];
    }

    if ( defined $deadline ) {
        my $new_timeout = $deadline - $now;
        $log->debugf( "setting alarm(now+%ds) for deadline(@%d)", $new_timeout, $deadline );
        my $old_timeout = alarm $new_timeout;
        if ($old_timeout) {
            $log->debugf( "got back alarm(now+%ds)", $old_timeout );
            $self->add_timeout($old_timeout);
        }
    }

    return;
}

1;
