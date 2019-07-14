package Unix::Signals;
use strict;
use warnings;

use Carp qw( confess );
use Exporter 'import';
use Readonly;
use Scalar::Util qw(looks_like_number);

Readonly our $SIGNALS => bless {
    transient => {},
    current   => {},
};

=head1 NAME

Unix::SignalHandler - An abstraction allowing cooperative use of signals.

=head1 SYNOPSIS

    use Unix::SignalHandler qw( $SIGNALS );

=head1 DESCRIPTION

Unix::SignalHandler allows consumers to detect caught signals in a robust way.

It splits time into periods separated by calls to the update() methods.

The was_caught() method tells wheter or not the given signal was caught in the
last completed period.

It is not possible to distinguish between signals being caught just once or
multiple times within a given period.
This matches the behavior of POSIX signal handling.

Use the set_handler() method to control what signals are tracked,

=head1 EXPORTS

=head2 $SIGNALS

The singleton instance of this class.

=cut

our @EXPORT_OK = qw( $SIGNALS );

=head1 INSTANCE METHODS

=head2 set_handler

Specify how the given signal should be handled.

    use Unix::SignalHandler qw( $SIGNALS );

    $SIGNALS->set_handler( 'INT', 'TRACK' );
    while ( !$SIGNALS->was_caught('INT') ) {
        sleep 1;
    }
    print STDERR "Received SIGINT\n";

=cut

sub set_handler {
    my $self    = shift;
    my $signame = shift;
    my $type    = shift;

    if ( $type eq 'TRACK' ) {
        $SIG{$signame} = \&_store;
    }
    elsif ( $type eq 'DEFAULT' ) {
        $SIG{$signame} = 'DEFAULT'
    }
    elsif ( $type eq 'IGNORE' ) {
        $SIG{$signame} = 'DEFAULT'
    }
    else {
        confess 'unexpected value in $type argument';
    }

    return;
}

sub update {
    my $self = shift;

    for my $signame ( keys %{ $self->{transient} } ) {
        if ( $self->{transient}{$signame} ) {
            $self->{transient}{$signame} = 0;
            $self->{current}{$signame}   = 1;
        }
        else {
            $self->{current}{$signame} = 0;
        }
    }

    return;
}

=head2 was_caught

Test if the given signal was caught during the last completed period.

    use Unix::SignalHandler qw( $SIGNALS );
    if ( $SIGNALS->was_caught( 'HUP' ) ) {
        print "SIGHUP\n";
    }

=cut

sub was_caught {
    my $self    = shift;
    my $signame = shift;

    return $self->{current}{$signame};
}

=head2 all_signals

Get all known signals.

    use Unix::SignalHandler qw( $SIGNALS );
    my @sig_names = $SIGNALS->all_signals();

=cut

sub all_signals {
    my $self = shift;

    return keys %SIG;
}

sub _store {
    my $signame = shift;

    $SIGNALS->{transient}{$signame} = 1;

    return;
}

1;
