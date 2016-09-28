package CatalystX::ASP;

use namespace::autoclean;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Types::Path::Tiny qw(Path Paths);
use Path::Tiny;
use Module::Runtime qw(require_module);
use Digest::MD5 qw(md5_hex);
use Carp;

with 'CatalystX::ASP::Compiler', 'CatalystX::ASP::Parser';

our $VERSION = '0.05';
our @CompileChecksumKeys = qw(Global GlobalPackage IncludesDir XMLSubsMatch);
our @Objects = qw(Application Session Response Server Request);

has 'c' => (
    is => 'ro',
    required => 1,
);

has 'Global' => (
    is => 'ro',
    isa => Path,
    coerce => 1,
    default => sub { path('/tmp') },
);

has 'GlobalPackage' => (
    is => 'ro',
    isa => 'Str',
);

has 'IncludesDir' => (
    is => 'ro',
    isa => Paths,
    coerce => 1,
    lazy => 1,
    default => sub { [ shift->Global() ] },
);

has 'MailHost' => (
    is => 'ro',
    isa => 'Str',
    default => 'localhost',
);

has 'MailFrom' => (
    is => 'ro',
    isa => 'Str',
    default => '',
);

subtype 'XMLSubsRegexp' => as 'Regexp';

coerce 'XMLSubsRegexp'
    => from 'Str'
        => via {
            $_ =~ s/\(\?\:([^\)]*)\)/($1)/isg;
            $_ =~ s/\(([^\)]*)\)/(?:$1)/isg;
            qr/$_/;
        };

has 'XMLSubsMatch' => (
    is => 'ro',
    isa => 'XMLSubsRegexp',
    coerce => 1,
);

has 'Debug' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

has '_include_file_cache' => (
    is => 'rw',
    isa => 'HashRef',
    traits => [ qw(Hash) ],
    handles => {
        _include_file_from_cache => 'get',
        _cache_include_file => 'set',
        _include_file_is_cached => 'exists',
    },
);

has '_compile_checksum' => (
    is => 'ro',
    isa => 'Str',
    default => sub {
        my $self = shift;
        md5_hex(
            join( '&-+',
                $VERSION,
                map { $self->$_ || '' } @CompileChecksumKeys
            )
        );
    },
);

for ( qw(Response Server Request GlobalASA) ) {
    my $class = join( '::', __PACKAGE__, $_ );
    require_module $class;
    has "$_" => (
        is => 'ro',
        isa => $class,
        lazy => 1,
        default => sub { $class->new( asp => shift ) }
    );
}

# Set up a global $Application hash for remainder of application life
our $application;
my $application_class = join( '::', __PACKAGE__, 'Application' );
require_module $application_class;
has 'Application' => (
    is => 'ro',
    isa => $application_class,
    lazy => 1,
    default => sub {
        my ( $self ) = @_;
        return $application ||= $application_class->new( asp => $self );
    },
);

my $session_class = join( '::', __PACKAGE__, 'Session' );
require_module $session_class;
has 'Session' => (
    is => 'ro',
    isa => $session_class,
    lazy => 1,
    default => sub {
        my ( $self ) = @_;
        my %session = ( asp => $self, _is_new => 0 );
        my $session_object = $session_class->new( %session );
        tie %session, $session_class, $session_object;
        $session{$_} = $session_object->{$_} for ( keys %$session_object );
        bless \%session, $session_class;
    },
);

sub BUILD {
    my ( $self ) = @_;

    # Trigger GlobalASA compilation now
    $self->GlobalASA;

    # Trigger Application creation now
    $self->Application;

    # Setup new Session
    $self->GlobalASA->Session_OnStart && $self->Session->_unset_is_new
        if $self->Session->_is_new;
}

sub search_includes_dir {
    my ( $self, $include ) = @_;

    return $self->_include_file_from_cache( $include )
        if $self->_include_file_is_cached( $include );

    for my $dir ( @{$self->IncludesDir} ) {
        my $file = $dir->child( $include );
        if ( $file->exists ) {
            return $self->_cache_include_file( $include => $file );
        }
    }

    # For includes of absolute filesystem path
    my $file = path( $include );
    if ( path( $self->c->config->{home} )->subsumes( $file ) && $file->exists ) {
        return $self->_cache_include_file( $include => $file );
    }

    return;
}

sub file_id {
    my ( $self, $file, $without_checksum ) = @_;

    my $checksum = $without_checksum ? $self->_compile_checksum : '';
    my @id;

    $file =~ s|/+|/|sg;
    $file =~ s/[\Wx]/_/sg;
    if ( length( $file ) >= 35 ) {
        push @id, substr( $file, length( $file ) - 35, 36 );
        # only do the hex of the original file to create a unique identifier for the long id
        push @id, 'x', md5_hex( $file . $checksum );
    } else {
        push @id, $file, 'x', $checksum;
    }

    return join( '', '__ASP_', @id );
}

sub execute {
    # shifting @_ because passing through arguments (from $Response->Include)
    my $self = shift;
    my $c = shift;
    my $code = shift;

    no strict qw(refs);
    no warnings;

    # This is to set up "global" ASP objects available directly in script or
    # in the "main" namespace
    for my $object ( @Objects ) {
        for my $namespace ( 'main', $self->GlobalASA->package ) {
            my $var = join( '::', $namespace, $object );
            $$var = $self->$object;
        }
    }

    # This will cause STDOUT to be captured and handled by Tie::Handle in the
    # Response class
    tie local *STDOUT, 'CatalystX::ASP::Response';

    local $SIG{__DIE__} = \&Carp::confess if $self->Debug;
    my @rv;
    if ( my $reftype = ref $code ) {
        if ( $reftype eq 'CODE' ) {
            # The most common case
            @rv = eval { &$code; };
        } elsif ( $reftype eq 'SCALAR' ) {
            # If $code is just a ref to a string, just send it to client
            $self->Response->WriteRef( $code );
        } else {
            $c->error( "Could not execute because \$code is a ref, but not CODE or SCALAR!" );
        }
    } else {
        # Alternatively, execute a function in the ASP context given a string of
        # the subroutine name
        # If absolute package already, then no need to set to package namespace
        my $subid = ( $code =~ /::/ ) ? $code : $self->GlobalASA->package . '::' . $code;
        @rv = eval { &$subid; };
    }
    if ( $@ ) {
        # Record errors if not $c->detach and $Response->End
        $c->error( "Error executing code: $@" ) unless $@ =~ m/catalyst_detach|asp_end/;

        # Passthrough $c->detach
        die $@ if $@ =~ m/catalyst_detach/;
    }

    return @rv;
}

__PACKAGE__->meta->make_immutable;
