package Config;
use strict;
use warnings;

sub new {
    my $class = shift;

    my $self = bless {}, $class;

    return $self;
}

sub load {
    my $self = shift;

    my $new_data = rand() < 0.5;

    $self->{data} ||= $new_data;

    return !!$new_data;
}

sub is_loaded {
    my $self = shift;

    return !!$self->{data};
}

sub timeout {
    return 5;
}

1;
