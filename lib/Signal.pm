package Signal;
use strict;
use warnings;

use Exporter qw( import );
use Scalar::Util qw(looks_like_number);

our @EXPORT_OK = qw( install_handler uninstall_handlers retrieve_caught );

my %CAUGHT;

sub install_handler {
    my $signame = shift;

    $SIG{$signame} = \&catch;

    return;
}

sub uninstall_handlers {
    for my $signame ( keys %SIG ) {
        if ( looks_like_number( $SIG{$signame} ) && $SIG{$signame} == \&catch ) {
            $SIG{$signame} = 'DEFAULT';
        }
    }

    return;
}

sub catch {
    my $signame = shift;

    $SIG{$signame} = \&catch;
    $CAUGHT{$signame} = 1;

    return;
}

sub retrieve_caught {
    my $signame = shift;

    if ( $CAUGHT{$signame} ) {
        $CAUGHT{$signame} = 0;
        return 1;
    }

    return 0;
}

1;
