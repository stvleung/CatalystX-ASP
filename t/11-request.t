#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib";

use Moose;
use Path::Tiny;
use Mock::CatalystX::ASP;

BEGIN { use_ok 'CatalystX::ASP'; }
BEGIN { use_ok 'CatalystX::ASP::Request'; }

my $root = path( $FindBin::Bin, '../t/lib/TestApp/root' )->realpath;

my $asp = CatalystX::ASP->new(
    c => mock_c,
    GlobalPackage => mock_asp->GlobalPackage,
    Global => $root,
);
my $Request = $asp->Request;

is( $Request->BinaryRead( 26 ),
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    '$Request->BinaryRead got correct data back'
);
is( $Request->ClientCertificate,
    undef,
    'Unimplemented method $Request->ClientCertificate'
);

done_testing;
