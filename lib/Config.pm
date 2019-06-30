package Config;
use strict;
use warnings;

use Carp qw( confess );

sub new {
    my ( $class, %args ) = @_;

    my $p_fail = delete $args{p_fail};

    !%args or confess 'unexpected arguments';

    my $self = bless {}, $class;

    $self->{p_fail} = $p_fail;

    return $self;
}

sub load {
    my $self = shift;

    if ($self->{p_fail} > 0 && rand() < $self->{p_fail} ) {
        warn "injected failure";
        return;
    }

    return 1;
}

sub is_loaded {
    my $self = shift;

    return !!$self->{data};
}

sub timeout {
    return 10;
}

1;
