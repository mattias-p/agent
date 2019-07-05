package Example::ConfigLoader;
use strict;
use warnings;

use Carp qw( confess );
use Config::IniFiles;
use Example::Config;

sub new {
    my ( $class, %args ) = @_;

    my $p_fail      = delete $args{p_fail};
    my $config_file = delete $args{config_file};

    !%args or confess 'unexpected arguments';

    my $self = bless {}, $class;

    $self->{p_fail}      = $p_fail;
    $self->{config_file} = $config_file;

    return $self;
}

sub load {
    my $self = shift;

    if ($self->{p_fail} > 0 && rand() < $self->{p_fail} ) {
        warn "injected failure";
        return;
    }

    my $cfg = Config::IniFiles->new( -file => $self->{config_file} );

    return Example::Config->new(
        dispatcher_timeout     => $cfg->val( 'dispatcher', 'timeout' ),
        dispatcher_max_workers => $cfg->val( 'dispatcher', 'max_workers' ),
        db_data_source         => $cfg->val( 'db',         'db_data_source' ),
        db_username            => $cfg->val( 'db',         'db_username' ),
        db_password            => $cfg->val( 'db',         'db_password' ),
    );
}

1;
