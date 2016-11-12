package Mock::CatalystX::ASP;

use Moose;
use Path::Tiny qw(path);
use FindBin qw($Bin);
use File::Temp;
use File::Slurp qw(write_file);
use Fcntl;

use parent 'Exporter';
our @EXPORT = qw(
    mock_c
    mock_asp
    mock_global_asa
);

require CatalystX::ASP;

my $mock_c;
my $mock_c_response;
my $mock_c_request;
my $mock_asp;
my $mock_logger;
my $mock_global_asa;

*file_id = *CatalystX::ASP::file_id;

sub mock_logger {
    $mock_logger //= Moose::Meta::Class->create_anon_class(
        methods => {
            warn => sub { 'does nothing!' },
            error => sub { 'does nothing!' },
        },
    )->new_object();
}

sub mock_c_response {
    $mock_c_response //= Moose::Meta::Class->create_anon_class(
        methods => {
            cookies => sub { { } },
        },
    )->new_object();
}

sub mock_c_request {
    $mock_c_request //= Moose::Meta::Class->create_anon_class(
        methods => {
            cookies => sub { { } },
            uploads => sub { { } },
            query_parameters => sub { { } },
            body_parameters => sub { { } },
            parameters => sub { { } },
            env => sub { { } },
            body => sub {
                my $body = File::Temp->new;
                print $body 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
                seek $body, 0, SEEK_SET;
                return $body;
            },
            content_length => sub { 0 },
            content_type => sub { 'application/x-www-form-urlencoded' },
            method => sub { 'GET' },
            path => sub { 'welcome.asp' }
        },
    )->new_object();
}

sub mock_c {
    $mock_c //= Moose::Meta::Class->create_anon_class(
        methods => {
            log => \&mock_logger,
            response => \&mock_c_response,
            request => \&mock_c_request,
            config => sub { { name => 'TestApp', home => path( __FILE__, '../../../TestApp' )->realpath } },
            error => sub { print STDERR "$_[1]\n"; },
            detach => sub { die 'catalyst_detach' },
            path_to => sub { path( __FILE__, '../../../TestApp/root/welcome.asp' )->realpath },
        },
    )->new_object();
}

sub mock_asp {
    $mock_asp //= Moose::Meta::Class->create_anon_class(
        roles => [ 'CatalystX::ASP::Parser', 'CatalystX::ASP::Compiler' ],
        methods => {
            c => \&mock_c,
            search_includes_dir => sub { path( $_[0]->IncludesDir, $_[1] ) },
            file_id => \&Mock::CatalystX::ASP::file_id,
            IncludesDir => sub { path( __FILE__, '../../../TestApp/root' )->realpath },
            GlobalPackage => sub { 'TestApp::ASP' },
            GlobalASA => \&mock_global_asa,
            XMLSubsMatch => sub { qr/parser:[\w\-]+/ },
            Debug => sub { 1 },
        },
    )->new_object();
}

sub mock_global_asa {
    $mock_global_asa //= Moose::Meta::Class->create_anon_class(
        methods => {
            exists => sub { 1 },
            execute_event => sub { 'does nothing!' },
            package => sub { mock_asp->GlobalPackage },
            Script_OnParse => sub { 'Script_OnParse event!' },
        },
    )->new_object();
}

1;
