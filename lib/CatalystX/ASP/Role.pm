package CatalystX::ASP::Role;

use Moose::Role;

before 'setup_components' => sub {
    my $class = shift;

    $class->inject_components(
        'View::ASP' => {
            from_component => 'CatalystX::ASP::View',
        }
    );

    $class->inject_components(
        'Controller::ASP' => {
            from_component => 'CatalystX::ASP::Controller',
        }
    );
};

no Moose::Role;

1;
