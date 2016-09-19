package CatalystX::ASP::Role;

use Moose::Role;

# Use this Role after loading Catalyst::Plugin::Session in order to utilize
# $Session

before 'setup_components' => sub {
    my $class = shift;
    $class->inject_components(
        'View::ASP' => {
            from_component => 'CatalystX::ASP::View',
        }
    );
};

no Moose::Role;

1;
