package App::Allocator;
use strict;
use warnings;

use Carp qw( confess );
use Log::Any qw( $log );

sub new {
    my ( $class, %args ) = @_;

    my $p_fail = delete $args{p_fail};

    !%args or confess 'unexpected arguments';

    my $self = bless {}, $class;

    $self->{jobs}   = {};
    $self->{p_fail} = $p_fail;

    return $self;
}

sub claim {
    my $self = shift;
    my $db   = shift;

    if ($self->{p_fail} > 0 && rand() < $self->{p_fail} ) {
        $log->warn("injected failure (allocator)");
        return;
    }

    my ($uid, $jid) = $db->unit_claim();

    if (!$uid) {
        return;
    }

    $self->{jobs}{$jid} = $uid;

    return ( $jid, $uid );
}

sub release {
    my $self = shift;
    my $db   = shift;
    my $jid  = shift;

    $db->unit_release( $jid );

    delete $self->{jobs}{$jid};

    return;
}

sub set_completed {
    my $self = shift;
    my $db   = shift;
    my $jid  = shift;

    $db->unit_set_completed( $jid );

    return;
}

sub get_unit_id {
    my $self = shift;
    my $jid  = shift;

    defined $self->{jobs}{$jid}[0] or confess "get_unit_id $jid";

    return $self->{jobs}{$jid}[0];
}

1;
