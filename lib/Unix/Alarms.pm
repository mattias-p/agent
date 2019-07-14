package Unix::Alarms;
use strict;
use warnings;

use Exporter 'import';
use Log::Any qw( $log );
use Set::Ordered::Array;
use Readonly;

Readonly our $ALARMS => bless { deadlines => Set::Ordered::Array->new() };

our @EXPORT_OK = qw( $ALARMS );

sub add_alarm {
    my $self      = shift;
    my $timestamp = shift;
    my $now       = shift;

    $now //= time();

    my $timeout = $timestamp - $now;

    $log->debugf( "adding alarm(@%d) i.e. now+%ds", $timestamp, $timeout );
    $self->{deadlines}->insert($timestamp);
    $self->refresh_alarm( $now );

    return;
}

sub refresh_alarm {
    my $self = shift;
    my $now  = shift;

    $now //= time();

    $self->{deadlines}->remove_le($now);
    my $deadline = $self->{deadlines}->peek_min();
    if ( $deadline ) {
        my $timeout = $deadline - $now;
        $log->debugf( "setting alarm(now+%ds) for deadline(@%d)",
            $timeout, $deadline );
        alarm($timeout);
    }

    return;
}

1;
