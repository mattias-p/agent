package Example::Job;
use strict;
use warnings;

use Carp qw( confess );
use Log::Any qw( $log );

sub new {
    my ( $class, %args ) = @_;

    my $db      = delete $args{db};
    my $job_id  = delete $args{job_id};
    my $item_id = delete $args{item_id};

    !%args or confess 'unexpected arguments';

    defined $db or confess "db argument must be defined";

    my $self = bless {}, $class;

    $self->{db}      = $db;
    $self->{job_id}  = $job_id;
    $self->{item_id} = $item_id;

    return $self;
}

sub job_id {
    my $self = shift;

    return $self->{job_id};
}

sub item_id {
    my $self = shift;

    return $self->{item_id};
}

sub set_db {
    my $self = shift;
    my $db   = shift;

    $self->{db} = $db;

    return;
}

sub run {
    my ( $self ) = @_;

    if ( rand() < 0.1 ) {
        $log->info("just about to derp");
        confess "derp";
    }

    my $t = 5 + rand(11);
    $log->infof( "job(%d:%d) pretending to work for %0.2fs", $self->{item_id}, $self->{job_id}, $t );
    sleep($t);               # pretend to do something

    $self->{db}->unit_set_completed($self->{job_id});

    return;
}

sub release {
    my $self = shift;

    $self->{db}->unit_release( $self->{job_id} );

    return;
}

1;
