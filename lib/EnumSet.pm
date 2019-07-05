package EnumSet;
use strict;
use warnings;

sub new {
    my ( $class, @symbols ) = @_;

    my $self = bless {}, $class;

    my $i = 0;
    $self->{sym_to_ord} = { map { $_ => $i++ } @symbols };
    $self->{queue} = [];

    return $self;
}

sub insert {
    my $self  = shift;
    my $event = shift;

    my $i = $self->{sym_to_ord}{$event};

    $self->{queue}[$i] = $event;

    return;
}

sub pop {
    my $self = shift;

    for my $i ( 0 .. $#{ $self->{queue} } ) {
        if ( $self->{queue}[$i] ) {
            my $value = $self->{queue}[$i];
            undef $self->{queue}[$i];
            return $value;
        }
    }
    return undef;
}

1;
