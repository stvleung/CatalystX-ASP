package CatalystX::ASP::Dispatcher;

use Moose;
use Catalyst::Action;

extends 'Catalyst::DispatchType';

use Catalyst::Utils;
use Text::SimpleTable;

=head1 NAME

CatalystX::ASP::Dispatcher - Catalyst DispatchType to match .asp requests

=head1 SYNOPSIS

  package MyApp;

  after 'setup_dispatcher' => sub {
    push @{ $shift->dispatcher->preload_dispatch_types }, '+CatalystX::ASP::Dispatcher';
  };

=head1 DESCRIPTION

This DispatchType will match any requests ending with .asp.

=cut

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

=head1 METHODS

=over

=item $self->list($c)

Debug output for ASP dispatch points

=cut

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

=item $self->match($c, $path)

Checks if request path ends with .asp, and if file exists. Then creates custom
action to forward to ASP View.

=cut

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

=item $self->register( $c, $action )

Registers the generated action

=cut

sub register {
    my ( $self, $c, $action ) = @_;

    return $self->_add_action( $action->name => 1 ) if $action->attributes->{ASP};
}

=item $self->uri_for_action($action, $captures)

Get a URI part for an action

=cut

sub uri_for_action {
    my ( $self, $c, $action, $captures ) = @_;

    return $action->private_path;
}

__PACKAGE__->meta->make_immutable;

=back

=head1 SEE ALSO

L<CatalystX::ASP::Role>, L<CatalystX::ASP::View>
