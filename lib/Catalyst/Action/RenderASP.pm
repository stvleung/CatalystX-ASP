package Catalyst::Action::RenderASP;

use namespace::autoclean;
use Moose;

extends 'Catalyst::Action';

sub execute {
    my $self = shift;
    my ( $controller, $c ) = @_;
    $self->next::method( @_ );
    $c->forward( $c->view( 'ASP' ) );
}

__PACKAGE__->meta->make_immutable;
