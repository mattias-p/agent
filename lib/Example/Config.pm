package Example::Config;
use strict;
use warnings;

use Carp qw( confess );

sub new {
    my ( $class, %args ) = @_;

    my $dispatcher_timeout     = delete $args{dispatcher_timeout};
    my $dispatcher_max_workers = delete $args{dispatcher_max_workers};
    my $db_data_source         = delete $args{db_data_source};
    my $db_username            = delete $args{db_username};
    my $db_password            = delete $args{db_password};
    !%args or confess 'unexpected arguments';

    my $self = bless {}, $class;

    $self->{dispatcher_timeout}     = $dispatcher_timeout;
    $self->{dispatcher_max_workers} = $dispatcher_max_workers;
    $self->{db_data_source}         = $db_data_source;
    $self->{db_username}            = $db_username;
    $self->{db_password}            = $db_password;

    return $self;
}

sub timeout {
    my $self = shift;

    return $self->{dispatcher_timeout};
}

sub max_workers {
    my $self = shift;

    return $self->{dispatcher_max_workers};
}

sub db_data_source {
    my $self = shift;

    return $self->{db_data_source};
}

sub db_username {
    my $self = shift;

    return $self->{db_username};
}

sub db_password {
    my $self = shift;

    return $self->{db_password};
}

sub update_dispatcher {
    my $self       = shift;
    my $dispatcher = shift;

    $dispatcher->set_max_workers( $self->max_workers );
    $dispatcher->set_timeout( $self->timeout );

    return;
}

1;
