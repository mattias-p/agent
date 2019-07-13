package Unix::SignalHandler;
use strict;
use warnings;

use Exporter 'import';
use Readonly;
use Scalar::Util qw(looks_like_number);

Readonly our $SIGNAL_HANDLER => bless {}, __PACKAGE__;

=head1 NAME

Unix::SignalHandler - A singleton class catching or ignoring signals

=head1 SYNOPSIS

    use Unix::SignalHandler qw( $SIGNAL_HANDLER );

=head1 DESCRIPTION

Unix::SignalHandler lets you install signal handlers that record caught signals so you
can check them later (e.g. in your main loop).

When you check a signal you can tell whether or not the signal has been caught
since the last check, but if it has been caught you cannot tell how many times.
Howver if a signal is caught you are guaranteed that it will not be lost,
but the next call to check will report it.

Additionally a method to ignore all signals is provided.

=head1 EXPORTS

=head2 $SIGNAL_HANDLER

The singleton instance of this class.

=cut

our @EXPORT_OK = qw( $SIGNAL_HANDLER );

=head1 INSTANCE METHODS

=head2 install_handler

Installs a handler for the given signal.

    $SIGNAL_HANDLER->install_handler('INT');

    while ( !$SIGNAL_HANDLER->retrieve_caught('INT') ) {
        sleep 1;
    }

    print STDERR "Received SIGINT\n";

=cut

sub install_handler {
    my $self    = shift;
    my $signame = shift;

    $SIG{$signame} = \&_catch;

    return;
}

=head2 retrieve_caught

Check and clear the flag for the given signal.

    if ( $SIGNAL_HANDLER->retrieve_caught( 'HUP' ) ) {
        print "Hung up!\n";
    }

=cut

sub retrieve_caught {
    my $self    = shift;
    my $signame = shift;

    if ( $SIGNAL_HANDLER->{$signame} ) {
        $SIGNAL_HANDLER->{$signame} = 0;
        return 1;
    }

    return 0;
}

=head2 ignore_all_signals

Set all signal handlers to IGNORE.

    use Unix::SignalHandler qw( $SIGNAL_HANDLER );
    $SIGNAL_HANDLER->ignore_all_signals();

=cut

sub ignore_all_signals {
    my $self = shift;

    for my $signame ( keys %SIG ) {
        $SIG{$signame} = 'IGNORE';
    }

    return;
}

sub _catch {
    my $signame = shift;

    $SIGNAL_HANDLER->{$signame} = 1;

    return;
}

1;
