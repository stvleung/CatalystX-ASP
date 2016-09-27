package CatalystX::ASP::Controller;

use Moose;

BEGIN { extends 'Catalyst::Controller' }

sub root : Chained('/') PathPart('') {
    my ( $self, $c, @args ) = @_;

    my $path = $c->request->path;
    if ( $path =~ m/\.asp$/
        && -f $c->path_to( 'root', $path ) ) {
            $c->forward( $c->view( 'ASP' ), \@args );
            return;
    }

    if ( $c->controller( 'Root' )->action_for( $path ) ) {
        $c->forward( $c->controller( 'Root' ), $path );
        return;
    } else {
        $c->detach( $c->controller( 'Root' ), 'default' );
    }
}

1;
