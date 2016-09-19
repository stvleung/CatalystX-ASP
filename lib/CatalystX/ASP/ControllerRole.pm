package CatalystX::ASP::ControllerRole;

use Moose::Role;
use MooseX::MethodAttributes::Role;

sub asp :Regex('\.asp$') : ActionClass('RenderASP') { }

no Moose::Role;

1;
