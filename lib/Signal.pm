package Signal;
use strict;
use warnings;

use Exporter qw( import );

our @EXPORT_OK = qw( install_handler retrieve_caught );

my %CAUGHT;

sub install_handler {
    my $signame = shift;

    $SIG{$signame} = \&catch;

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
