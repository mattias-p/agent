package Unix::WaitStatus;
use strict;
use warnings;

use Config;
use POSIX ":sys_wait_h";
use Readonly;

Readonly my @SIG_NAMES => ( split ' ', $Config{sig_name} );

=head1 NAME

Unix::WaitStatus - A helper class for interpreting ${^CHILD_ERROR_NATIVE}.

=head1 SYNOPSIS

    my $status = Unix::WaitStatus->new( ${^CHILD_ERROR_NATIVE} );
    print $status->message, "\n";

=head1 CONSTRUCTOR

Construct a new Unix::WaitStatus for a given ${^CHILD_ERROR_NATIVE} value.

=cut

sub new {
    my $class  = shift;
    my $status = shift;

    my $inner = $status;
    my $self = bless \$inner, $class;

    return $self;
}

=head1 METHODS

=head2 is_not_found

Test if the status indicates that the PID does not exist.

=cut

sub is_not_found {
    my $self = shift;

    return $$self < 0;
}

=head2 is_exit_ok

Test if the status indicates that the process exited with a zero status code.

=cut

sub is_exit_ok {
    my $self = shift;
    return WIFEXITED( $$self ) && WEXITSTATUS($$self) == 0;
}

=head2 is_stopsig

Test if the status indicates that the process was stopped due to a signal.

=cut

sub is_stopsig {
    my $self = shift;
    return WIFSTOPPED( $$self );
}

=head2 message

Get a human readable string describing the status.

=cut

sub message {
    my ( $self ) = @_;

    if ( $$self < 0 ) {
        return "does not exist";
    }
    elsif ( WIFEXITED( $$self ) ) {
        my $exit_status = WEXITSTATUS($$self);
        if ( $exit_status == 0 ) {
            return sprintf "terminated successfully";
        }
        else {
            return sprintf "terminated normally with exit status $exit_status";
        }
    }
    elsif ( WIFSIGNALED( $$self ) ) {
        my $sig_num = WTERMSIG($$self);
        return sprintf "terminated due to uncaught signal %s",
          _sig_name_human($sig_num);
    }
    elsif ( WIFSTOPPED( $$self ) ) {
        my $sig_num = WSTOPSIG($$self);
        return sprintf "stopped by signal %s",
          _sig_name_human($sig_num);
    }
    else {
        return "in unknown state $$self";
    }
}

sub _sig_name_human {
    my $sig_num = shift;

    my $sig_name = $SIG_NAMES[$sig_num];
    return (
        ( defined $sig_name )
        ? "$sig_num (SIG" . $sig_name . ")"
        : $sig_num
    );
}

1;
