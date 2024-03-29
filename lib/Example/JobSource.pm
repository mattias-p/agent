package Example::JobSource;
use strict;
use warnings;

use Example::Job;
use Carp qw( confess );
use Log::Any qw( $log );

sub new {
    my ( $class, %args ) = @_;

    my $db     = delete $args{db};
    my $p_fail = delete $args{p_fail};

    !%args or confess 'unexpected arguments';

    my $self = bless {}, $class;

    $self->{db}     = $db;
    $self->{p_fail} = $p_fail;

    return $self;
}

sub claim_job {
    my $self = shift;

    if ($self->{p_fail} > 0 && rand() < $self->{p_fail} ) {
        $log->warn("injected failure (allocator)");
        return;
    }

    my ($uid, $jid) = $self->{db}->unit_claim();

    if (!$uid) {
        return;
    }

    return Example::Job->new(
        db      => $self->{db},
        job_id  => $jid,
        item_id => $uid,
    );
}

sub set_db {
    my $self = shift;
    my $db   = shift;

    $self->{db} = $db;

    return;
}

1;
