package Example::DB;
use strict;
use warnings;

use Carp qw( confess );
use DBI;
use Readonly;

Readonly my $FIRST_UNIT_ID  => 1;
Readonly my $FIRST_CLAIM_ID => 10001;

sub connect {
    my ($class, %args) = @_;

    my $config = delete $args{config};

    !%args or confess "unexpected arguments";

    my $self = bless {}, $class;

    $self->{dbh} = DBI->connect(
        $config->db_data_source,
        $config->db_username,
        $config->db_password,
        { AutoCommit => 1, RaiseError => 1, PrintError => 0 }
    );

    return $self;
}

sub disconnect {
    my $self = shift;

    $self->{dbh}->disconnect;

    return;
}

sub create_schema {
    my $self = shift;
    $self->{dbh}->do(
        qq(
            create table if not exists `LastClaimId` (
                `claim_id`   integer   not null
            );
        )
    );
    $self->{dbh}->prepare(
        qq(
            insert or ignore into `LastClaimId` (rowid, claim_id) values (1, ?)
        )
    )->execute($FIRST_CLAIM_ID);

    $self->{dbh}->do(
        qq(
            create table if not exists `LastUnitId` (
                `unit_id`   integer   not null
            );
        )
    );
    $self->{dbh}->prepare(
        qq(
            insert or ignore into `LastUnitId` (rowid, unit_id) values (1, ?)
        )
    )->execute($FIRST_UNIT_ID);

    $self->{dbh}->do(
        qq(
            create table if not exists `Units` (
                `unit_id`     integer   not null,
                `claim_id`    integer   null,
                `completed`   boolean   not null   default false
            );
        )
    );
    return;
}

sub unit_new {
    my $self      = shift;
    my $timestamp = shift;

    $self->{update_last_unit_id} //= $self->{dbh}->prepare(
        qq(
            update `LastUnitId` set `unit_id` = `unit_id` + 1
        )
    );
    $self->{insert_unit} //= $self->{dbh}->prepare(
        qq(
            insert into `Units` (`unit_id`)
            select `unit_id` from `LastUnitId`
        )
    );
    $self->{select_last_unit_id} //= $self->{dbh}->prepare(
        qq(
            select `unit_id` from `LastUnitId`
        )
    );

    my $unit_id;
    local $self->{dbh}->{AutoCommit} = 0;
    eval {
        $self->{update_last_unit_id}->execute();
        $self->{insert_unit}->execute();
        $self->{select_last_unit_id}->execute();
        $unit_id =
          $self->{dbh}->selectrow_array( $self->{select_last_unit_id} );
        $self->{dbh}->commit;
    };
    if ( my $e = $@ ) {
        eval { $self->{dbh}->rollback };
        die $e;
    }
    return $unit_id;
}

sub unit_claim {
    my $self = shift;
    my $timestamp = shift;

    $self->{find_unclaimed} //= $self->{dbh}->prepare(
        qq(
            select `unit_id` from `Units` where `completed` = false and `claim_id` is null limit 1
        )
    );
    $self->{update_claim} //= $self->{dbh}->prepare(
        qq(
            update `Units` set `claim_id` = ? where `unit_id` = ?
        )
    );
    $self->{update_last_claim_id} //= $self->{dbh}->prepare(
        qq(
            update `LastClaimId` set `claim_id` = `claim_id` + 1
        )
    );
    $self->{select_last_claim_id} //= $self->{dbh}->prepare(
        qq(
            select `claim_id` from `LastClaimId`
        )
    );

    local $self->{dbh}->{AutoCommit} = 0;
    my ( $uid, $cid );
    eval {
        ($uid) = $self->{dbh}->selectrow_array( $self->{find_unclaimed} );
        if ($uid) {
            $self->{update_last_claim_id}->execute() or die;
            $self->{select_last_claim_id}->execute() or die;
            ($cid) =
              $self->{dbh}->selectrow_array( $self->{select_last_claim_id} )
              or die;
            $self->{update_claim}->execute( $cid, $uid ) or die;
        }
        $self->{dbh}->commit or die;
    };
    if ( my $e = $@ ) {
        eval { $self->{dbh}->rollback };
        die $e;
    }

    return ($uid, $cid);
}

sub unit_set_completed {
    my $self = shift;
    my $cid = shift;

    $self->{complete_unit} //= $self->{dbh}->prepare(
        qq(
            update `Units` set `completed` = 1 where `claim_id` = ?
        )
    );

    $self->{complete_unit}->execute( $cid ) or die $self->{dbh}->errstr;

    return;
}

sub unit_release {
    my $self = shift;
    my $cid  = shift;

    $self->{release_unit} //= $self->{dbh}->prepare(
        qq(
            update `Units` set `claim_id` = null where `claim_id` = ?
        )
    );

    my $rv = $self->{release_unit}->execute( $cid );

    return $rv;
}

1;
