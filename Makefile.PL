use 5.006;
use strict;
use warnings;
use inc::Module::Install;

name 'CatalystX-ASP';
all_from 'lib/CatalystX/ASP.pm';
author q{Steven Leung <sleung@cpan.org>};
license 'perl';

perl_version 5.006;

tests_recursive( 't' );

resources(
    license    => 'http://dev.perl.org/licenses/',
    repository => 'https://github.com/stvleung/CatalystX-ASP.git',
    bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=CatalystX-ASP',
);

configure_requires(
    'Module::Install' => 0,
);

build_requires(
    'Test::More' => 0,
);

requires(
    'Carp'                      => 0,
    'Catalyst'                  => 5.90000,
    'Digest::MD5'               => 0,
    'File::Slurp'               => 0,
    'HTML::Entities'            => 0,
    'HTTP::Date'                => 0,
    'List::Util'                => 0,
    'Module::Runtime'           => 0,
    'Moose'                     => 0,
    'MooseX::Types::Path::Tiny' => 0,
    'namespace::autoclean'      => 0,
    'Path::Tiny'                => 0,
    'Scalar::Util'              => 0,
    'Text::SimpleTable'         => 0,
    'Tie::Handle'               => 0,
    'Tie::Hash'                 => 0,
    'Try::Tiny'                 => 0,
    'URI::Escape'               => 0,
    'URI'                       => 0,
);

test_requires(
    'Catalyst::Plugin::Session'                => 0,
    'Catalyst::Plugin::Session::State::Cookie' => 0,
    'Catalyst::Plugin::Session::Store::File'   => 0,
    'Text::Lorem'                              => 0,
);

install_as_cpan;
auto_install;
WriteAll;
