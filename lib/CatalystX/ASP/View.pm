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
    my ( $self, $c, @args ) = @_;

    my $path = join '/', @args;
    $self->render( $c, $path );

    my $resp = $self->asp->Response;

    my $charset = $resp->Charset;
    my $content_type = $resp->ContentType;
    $content_type .= "; charset=$charset" if $charset;
    $c->response->content_type( $content_type );
    for my $name ( keys %{$resp->Cookies} ) {
        $c->response->cookies->{$name}{value} = $resp->Cookies->{$name};
    }
    $c->response->header( Cache_Control => $resp->CacheControl );
    $c->response->header( Expires => time2str( time + $resp->Expires ) ) if $resp->Expires;
    $c->response->status( $resp->Status || 200 );
    $c->response->body( $resp->Body );

    return 1;
}

sub render {
    my ( $self, $c, $path ) = @_;


    my $asp = $self->asp( CatalystX::ASP->new({ %{$c->config->{'CatalystX::ASP'}}, c => $c }) );

    eval {
        my $compiled = $asp->compile_file( $c, $c->path_to( 'root', $path || $c->request->path ) );

        $asp->GlobalASA->Script_OnStart;
        $asp->execute( $c, $compiled->{code} );
        $asp->GlobalASA->Script_OnEnd;
    };
    if ( $@ ) {
        # If error in other ASP code, return HTTP 500
        if ( $@ !~ m/catalyst_detach|asp_end/ && ! $c->has_errors ) {
            $c->error( "Encountered application error: $@" )
        }

        # Passthrough $c->detach
        die $@ if $@ =~ m/catalyst_detach/;
    }
}

__PACKAGE__->meta->make_immutable;
