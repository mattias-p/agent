package App::Allocator;
use strict;
use warnings;

use Carp qw( confess );

sub new {
    my ( $class, %args ) = @_;

    my $p_fail = delete $args{p_fail};

    !%args or confess 'unexpected arguments';

    my $self = bless {}, $class;

    $self->{counter} = 0;
    $self->{p_fail}  = $p_fail;

    return $self;
}

sub claim {
    my $self = shift;

    if ($self->{p_fail} > 0 && rand() < $self->{p_fail} ) {
        warn "injected failure";
        return;
    }

    $self->{counter} += 1;
    return $self->{counter};
}

sub release {
    my $self = shift;
    my $id   = shift;

    return;
}

1;
