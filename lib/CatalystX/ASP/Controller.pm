package CatalystX::ASP::Controller;

use Moose;

BEGIN { extends 'Catalyst::Controller' }

sub asp :Regex('\.asp$') : ActionClass('RenderASP') { }

1;
