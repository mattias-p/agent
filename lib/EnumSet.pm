package EnumSet;
use strict;
use warnings;

sub new {
    my ( $class ) = @_;

    my $self = bless {}, $class;

    $self->{elements} = [];

    return $self;
}

sub insert {
    my $self  = shift;
    my $value = shift;

    my $index = ($value =~ s/\D//gr);

    $self->{elements}[$index] = $value;

    return;
}

sub pop {
    my $self = shift;

    for my $index ( 0 .. $#{ $self->{elements} } ) {
        if ( $self->{elements}[$index] ) {
            my $value = $self->{elements}[$index];
            undef $self->{elements}[$index];
            return $value;
        }
    }
    return undef;
}

1;
