package CatalystX::ASP::View;

use namespace::autoclean;
use Moose;
use CatalystX::ASP;
use HTTP::Date;

extends 'Catalyst::View';

has 'asp' => (
    is => 'rw',
    isa => 'CatalystX::ASP',
);

sub process {
    my ( $self, $c ) = @_;

    my $body = $self->render( $c );
    my $resp = $self->asp->Response;

    my $charset = $resp->Charset;
    my $content_type = $resp->ContentType;
    $content_type .= "; charset=$charset" if $charset;
    $c->response->content_type( $content_type );
    $c->response->header( Cache_Control => $resp->CacheControl );
    $c->response->header( Expires => time2str( time + $resp->Expires ) ) if $resp->Expires;
    $c->response->status( $resp->Status || 200 );
    $c->response->body( $body );

    return 1;
}

sub render {
    my ( $self, $c ) = @_;

    my $asp = $self->asp( CatalystX::ASP->new({ %{$c->config->{'CatalystX::ASP'}}, c => $c }) );
    eval {

        my $compiled = $asp->compile_file( $c, $c->path_to( 'root', $c->request->path ) );

        $asp->GlobalASA->Script_OnStart;
        $asp->execute( $c, $compiled->{code} );
        $asp->GlobalASA->Script_OnEnd;
    };
    if ( my $error = $@ ) {
        die $error if $error !~ m/asp_end/;
    }
    return $asp->Response->Body;
}

__PACKAGE__->meta->make_immutable;
