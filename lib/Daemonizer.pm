package Daemonizer;
use strict;
use warnings;

use Proc::Daemon;

sub new {
    my ( $class, %args ) = @_;
    my $work_dir = delete $args{work_dir};
    my $pid_file = delete $args{pid_file};
    my $out_file = delete $args{out_file};

    my $self = bless {}, $class;

    $self->{work_dir} = $work_dir;
    $self->{pid_file} = $pid_file;
    $self->{out_file} = $out_file;

    return $self;
}

sub daemonize {
    my $self = shift;

    my $daemon = Proc::Daemon->new();
    return $daemon->Init(
        {
            work_dir     => $self->{work_dir},
            pid_file     => $self->{pid_file},
            child_STDERR => $self->{out_file},
            child_STDOUT => $self->{out_file},
        }
    );
}

1;
