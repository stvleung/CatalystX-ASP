package CatalystX::ASP::Role;

use Moose::Role;

# Inject our View
before 'setup_components' => sub {
    my $class = shift;

    $class->inject_components(
        'View::ASP' => {
            from_component => 'CatalystX::ASP::View',
        }
    );
};

# Register our DispatchType
after 'setup_dispatcher' => sub {
    my $c = shift;

    # Add our dispatcher
    push @{ $c->dispatcher->preload_dispatch_types }, '+CatalystX::ASP::Dispatcher';

    return $c;
};

no Moose::Role;

1;
