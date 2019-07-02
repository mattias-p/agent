package App::Worker;
use strict;
use warnings;

use Carp qw( confess );
use Log::Any '$log';

sub new {
    my ($class, %args) = @_;

    my $setup  = delete $args{setup};
    my $db     = delete $args{db};
    my $config = delete $args{config};

    !%args or confess 'unexpected arguments';

    my $self = bless {}, $class;

    $self->{setup}   = $setup;
    $self->{db}     = $db;
    $self->{config} = $config;

    return $self;
}

sub setup {
    my $self = shift;

    $self->{setup}->();
    $self->{dbh} = $self->{db}->connect( config => $self->{config} );
}

sub work {
    my ( $self, $jid, $uid ) = @_;

    my $t = 5 + rand(11);
    $log->infof( "job(%d:%d) pretending to work for %0.2fs", $uid, $jid, $t );
    sleep($t);               # pretend to do something

    $self->{dbh}->unit_set_completed($jid);

    return;
}

sub dbh {
    my $self = shift;

    return $self->{dbh};
}

1;
