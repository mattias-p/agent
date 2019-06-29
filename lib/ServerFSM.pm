package ServerFSM;
use strict;
use warnings;

use Exporter qw( import );
use FSM::Builder;
use Readonly;

our @EXPORT_OK = qw( new_server_fsm $S_START $S_LOAD $S_RUN $S_GRACE $S_SHUTDOWN $S_EXIT $I_DEFAULT $I_HUP $I_TERM $I_EXIT );

Readonly our $S_START    => 'START';
Readonly our $S_LOAD     => 'LOAD';
Readonly our $S_RUN      => 'RUN';
Readonly our $S_GRACE    => 'GRACE';
Readonly our $S_SHUTDOWN => 'SHUTDOWN';
Readonly our $S_EXIT     => 'EXIT';

Readonly our $I_DEFAULT => 'default';
Readonly our $I_HUP     => 'hup';
Readonly our $I_TERM    => 'term';
Readonly our $I_EXIT    => 'exit';

Readonly my $BUILDER => FSM::Builder->new();

$BUILDER->define_input(
    $I_DEFAULT => (
        $S_LOAD     => $S_RUN,
        $S_RUN      => $S_RUN,
        $S_GRACE    => $S_GRACE,
        $S_SHUTDOWN => $S_EXIT,
        $S_EXIT     => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_HUP => (
        $S_LOAD     => $S_LOAD,
        $S_RUN      => $S_LOAD,
        $S_GRACE    => $S_GRACE,
        $S_SHUTDOWN => $S_EXIT,
        $S_EXIT     => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_TERM => (
        $S_LOAD     => $S_GRACE,
        $S_RUN      => $S_GRACE,
        $S_GRACE    => $S_SHUTDOWN,
        $S_SHUTDOWN => $S_EXIT,
        $S_EXIT     => $S_EXIT,
    )
);

$BUILDER->define_input(
    $I_EXIT => (
        $S_LOAD     => $S_SHUTDOWN,
        $S_RUN,     => $S_SHUTDOWN,
        $S_GRACE    => $S_SHUTDOWN,
        $S_SHUTDOWN => $S_EXIT,
        $S_EXIT     => $S_EXIT,
    )
);

sub new_server_fsm {
    return $BUILDER->build( initial_state => $S_LOAD );
}

1;
