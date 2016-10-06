package CatalystX::ASP::Role;

use Moose::Role;

=head1 NAME

CatalystX::ASP::Role - Catalyst Role to plug-in the ASP View

=head1 SYNOPSIS

  package MyApp;

  use Moose;
  use Catalyst;
  extends 'Catalyst';

  with 'CatalystX::ASP::Role';

=head1 DESCRIPTION

Compose this role in your main application class. This will inject the ASP View
as View component in your app called 'ASP', accessible via
C<< $c->view('ASP') >>. It will also add a C<DispatchType> which will direct all
requests with C<.asp> extension to the View.

=head1 ATTRIBUTES

=over

=item asp

The ASP object available for the $context object

=cut

has 'asp' => (
    is => 'rw',
    isa => 'CatalystX::ASP',
    weak_ref => 1,
);

=back

=head1 METHODS

=over

=item before 'setup_components'

Inject C<CatalystX::ASP::View> component as a View for your app

=cut

# Inject our View
before 'setup_components' => sub {
    my $class = shift;

    $class->inject_components(
        'View::ASP' => {
            from_component => 'CatalystX::ASP::View',
        }
    );
};

=item after 'setup_dispatcher'

Load C<CatalystX::ASP::Dispatcher> as a C<DispatchType> for your app

=cut

# Register our DispatchType
after 'setup_dispatcher' => sub {
    my $c = shift;

    # Add our dispatcher
    push @{ $c->dispatcher->preload_dispatch_types }, '+CatalystX::ASP::Dispatcher';

    return $c;
};

no Moose::Role;

1;

=back

=head1 SEE ALSO

L<CatalystX::ASP::View> L<CatalystX::ASP::Dispatcher>
