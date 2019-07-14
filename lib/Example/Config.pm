package Example::Config;
use strict;
use warnings;

use Carp qw( confess );

sub new {
    my ( $class, %args ) = @_;

    my $tasks_timeout     = delete $args{tasks_timeout};
    my $tasks_max_workers = delete $args{tasks_max_workers};
    my $db_data_source    = delete $args{db_data_source};
    my $db_username       = delete $args{db_username};
    my $db_password       = delete $args{db_password};
    !%args or confess 'unexpected arguments';

    my $self = bless {}, $class;

    $self->{tasks_timeout}     = $tasks_timeout;
    $self->{tasks_max_workers} = $tasks_max_workers;
    $self->{db_data_source}    = $db_data_source;
    $self->{db_username}       = $db_username;
    $self->{db_password}       = $db_password;

    return $self;
}

sub timeout {
    my $self = shift;

    return $self->{tasks_timeout};
}

sub max_workers {
    my $self = shift;

    return $self->{tasks_max_workers};
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

sub update_task_manager {
    my $self         = shift;
    my $task_manager = shift;

    $task_manager->set_max_workers( $self->max_workers );

    return;
}

1;
