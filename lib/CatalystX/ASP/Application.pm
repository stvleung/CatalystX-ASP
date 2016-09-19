package CatalystX::ASP::Application;

use namespace::autoclean;
use Moose;

has 'asp' => (
    is => 'ro',
    isa => 'CatalystX::ASP',
    required => 1,
);

# TODO: will not implement
sub Lock {
    my ( $self ) = @_;
    $self->asp->c->log->warn( "\$Application->Lock has not been implemented!" );
    return;
}

# TODO: will not implement
sub UnLock {
    my ( $self ) = @_;
    $self->asp->c->log->warn( "\$Application->UnLock has not been implemented!" );
    return;
}

sub GetSession {
    my ( $self, $sess_id ) = @_;
    my $c = $self->asp->c;
    my $session_class = ref $self->asp->Session;
    if ( $c->can( 'get_session_data' ) ) {
        my $session = $c->get_session_data( $sess_id );
        $session->{asp} = $self->asp;
        return bless $session, $session_class
    } elsif ( $c->can( 'session_cache' ) ) {
        my $session = $c->session_cache->get( $sess_id );
        $session->{asp} = $self->asp;
        return bless $session, $session_class
    } else {
        return $self->asp->Session;
    }
}

# TODO: will not implement
sub SessionCount {
    my ( $self ) = @_;
    $self->asp->c->log->warn( "\$Application->SessionCount has not been implemented!" );
    return;
}

sub DEMOLISH { shift->asp->GlobalASA->Application_OnEnd }

__PACKAGE__->meta->make_immutable;
