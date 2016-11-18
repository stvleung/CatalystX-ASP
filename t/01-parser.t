#!perl
use 5.006;
use strict;
use warnings;
use Test::More tests => 14;
use Test::Exception;

use FindBin;
use lib "$FindBin::Bin/lib";

use Moose;
use File::Temp qw(tempfile);
use Mock::CatalystX::ASP;

my ( $script, $parsed_object );
my ( $fh, $filename );

# Test simple parsing
$script = q|<p><%= 'foo' %></p>|;
$parsed_object = mock_asp->parse( mock_c, \$script );
like(
    ${ $parsed_object->{data} },
    qr/\$Response->WriteRef\(.*'foo'/,
    'Parsed $script ref, converted <%= %> to $Response->WriteRef'
);
ok( $parsed_object->{is_perl}, 'Parser detected perl code' );

# Test simple parsing on file
( $fh, $filename ) = tempfile;
$fh->autoflush(1);
print $fh $script;
$parsed_object = mock_asp->parse_file( mock_c, $filename );
like(
    ${ $parsed_object->{data} },
    qr/\$Response->WriteRef\(.*'foo'/,
    'Parsed file, converted <%= %> to $Response->WriteRef'
);
ok( $parsed_object->{is_perl}, 'Parser detected perl code' );
is( $parsed_object->{file}, $filename, 'Parser saved name of file' );

throws_ok { $parsed_object = mock_asp->parse_file( mock_c, '' ) } qr/catalyst_detach/, 'Detached on parsing failure';

# Test parsing XMLSubs with content in block
$script = q|<parser:test arg1='foo' arg2='bar'>inner html</parser:test>|;
$parsed_object = mock_asp->parse( mock_c, \$script );
like(
    ${ $parsed_object->{data} },
    qr/parser::test\(\s*\{\s*['"]?arg1['"]?\s*=>\s*'foo'\s*,\s*['"]?arg2['"]?\s*=>\s*'bar'\s*\}\s*,\s*['"]inner html['"]\s*\)/,
    'Parsed $script ref, translated XMLSubs to perl function call'
);

# Test parsing XMLSubs with ASP in block
$script = q|<parser:test arg1='foo' arg2='bar'><%= 'inner html' %></parser:test>|;
$parsed_object = mock_asp->parse( mock_c, \$script );
like(
    ${ $parsed_object->{data} },
    qr/parser::test\(\s*\{\s*['"]?arg1['"]?\s*=>\s*'foo'\s*,\s*['"]?arg2['"]?\s*=>\s*'bar'\s*\}\s*,.*['"]inner html['"].*\)/,
    'Parsed $script ref, translated complex XMLSubs with ASP within block'
);

# Test parsing XMLSubs with no content block within
$script = q|<parser:test arg1='foo' arg2='bar'/>|;
$parsed_object = mock_asp->parse( mock_c, \$script );
like(
    ${ $parsed_object->{data} },
    qr/parser::test\(\s*\{\s*['"]?arg1['"]?\s*=>\s*'foo'\s*,\s*['"]?arg2['"]?\s*=>\s*'bar'\s*\}.*\)/,
    'Parsed $script ref, translated XMLSubs with no content block within'
);

# Test parsing nested XMLSubs
$script = q|<parser:test arg1='foo' arg2='bar'>Hello <parser:test body='World!'/></parser:test>|;
$parsed_object = mock_asp->parse( mock_c, \$script );
like(
    ${ $parsed_object->{data} },
    qr/parser::test\(\s*\{\s*['"]?arg1['"]?\s*=>\s*'foo'\s*,\s*['"]?arg2['"]?\s*=>\s*'bar'\s*\}.*Hello.*parser::test\(\s*\{\s*['"]?body['"]?\s*=>\s*'World!'.*\)/,
    'Parsed $script ref, nested XMLSubs'
);

# Test parsing for SSI
$script = q|<!--#include file="templates/some_template.tmpl"-->|;
$parsed_object = mock_asp->parse( mock_c, \$script );
like(
    ${ $parsed_object->{data} },
    qr/\$Response->Include\(\s*['"]templates\/some_template.tmpl['"].*\)/,
    'Parsed $script ref, convert SSI to ASP $Response->Include'
);

# Test parsing for SSI with arguments
$script = q|<!--#include file="templates/some_template.tmpl" args="foobar"-->|;
$parsed_object = mock_asp->parse( mock_c, \$script );
like(
    ${ $parsed_object->{data} },
    qr/\$Response->Include\(\s*['"]templates\/some_template.tmpl['"]\s*,\s*['"]foobar['"].*\)/,
    'Parsed $script ref, convert SSI to ASP $Response->Include'
);

# Test parsing on plain HTML
$script = q|<p>no asp!</p>|;
$parsed_object = mock_asp->parse( mock_c, \$script );
is(
    ${ $parsed_object->{data} },
    $script,
    'Parsed $script ref, does nothing for plain HTML'
);
ok( $parsed_object->{is_raw}, 'Parser marked raw file' );
