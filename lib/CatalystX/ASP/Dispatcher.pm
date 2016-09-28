package CatalystX::ASP::Dispatcher;

use Moose;
use Catalyst::Action;

extends 'Catalyst::DispatchType';

use Catalyst::Utils;
use Text::SimpleTable;

has '_actions' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
    traits => [ qw(Hash) ],
    handles => {
        _has_action => 'exists',
        _add_action => 'set',
    },
);

sub list {
    my ( $self, $c ) = @_;
    my $avail_width = Catalyst::Utils::term_width() - 9;
    my $col1_width = ($avail_width * .50) < 35 ? 35 : int($avail_width * .50);
    my $col2_width = $avail_width - $col1_width;
    my $asp = Text::SimpleTable->new(
        [ $col1_width, 'Path' ], [ $col2_width, 'Private' ]
    );
    $asp->row( '/*.asp', '/asp' );

    $c->log->debug( "Loaded ASP actions:\n" . $asp->draw . "\n" );
}

sub match {
    my ( $self, $c, $path ) = @_;

    if ( $path =~ m/\.asp$/ && -f $c->path_to( 'root', $path ) ) {
        my $namespace = '';
        my $action = Catalyst::Action->new(
            name => 'asp',
            code => sub {
                my ( $self, $c, @args ) = @_;
                $c->forward( $c->view( 'ASP' ), \@args );
            },
            reverse => '.asp',
            namespace => $namespace,
            class => 'CatalystX::ASP::Controller',
            attributes => [ qw(ASP) ],
        );

        $c->req->action( $path );
        $c->req->match( $path );
        $c->action( $action );
        $c->namespace( $namespace );
        return 1;
    }

    return 0;
}

sub register {
    my ( $self, $c, $action ) = @_;

    return $self->_add_action( $action->name => 1 ) if $action->attributes->{ASP};
}

sub uri_for_action {
    my ( $self, $c, $action, $captures ) = @_;

    return $action->private_path;
}

__PACKAGE__->meta->make_immutable;
