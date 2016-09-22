package CatalystX::ASP::Response;

use namespace::autoclean;
use Moose;
use Tie::Handle;
use Data::Dumper;

has 'asp' => (
    is => 'ro',
    isa => 'CatalystX::ASP',
    required => 1,
);

has '_flushed_offset' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);

has 'BinaryRef' => (
    is => 'rw',
    isa => 'ScalarRef',
    default => sub { \( shift->Body ) }
);

has 'Body' => (
    is => 'rw',
    isa => 'Str',
    traits => [ 'String' ],
    handles => {
        Write => 'append',
        BodyLength => 'length',
        BodySubstr => 'substr',
    },
);

# This attribute has no effect
has 'Buffer' => (
    is => 'rw',
    isa => 'Bool',
    default => 1,
);

has 'CacheControl' => (
    is => 'rw',
    isa => 'Str',
    default => 'private',
);

has 'Charset' => (
    is => 'rw',
    isa => 'Str',
    default => '',
);

# This attribute has no effect
has 'Clean' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);

has 'ContentType' => (
    is => 'rw',
    isa => 'Str',
    default => 'text/html',
);

# For some reason, for attributes that start with a capital letter, Moose seems
# to load the default value before the object is fully initialized. lazy => 1 is
# a workaround to build the defaults later
has 'Cookies' => (
    is => 'rw',
    isa => 'HashRef',
    reader => '_get_Cookies',
    writer => '_set_Cookies',
    lazy => 1,
    default => sub {
        my ( $self ) = @_;
        my $c = $self->asp->c;
        my %cookies;
        for my $name ( keys %{$c->response->cookies} ) {
            $cookies{$name} = $c->response->cookies->{$name}{value};
        }
        return \%cookies;
    },
    traits => [ 'Hash' ],
    handles => {
        _get_Cookie => 'get',
        _set_Cookie => 'set',
    },
);

# This attribute currently has no effect
has 'Debug' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
    reader => '_Debug',
);

has 'Expires' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);

# This attribute has no effect
has 'ExpiresAbsolute' => (
    is => 'rw',
    isa => 'Str',
    default => '',
);

# This attribute has no effect
has 'FormFill' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

# This attribute has no effect
has 'IsClientConnected' => (
    is => 'rw',
    isa => 'Bool',
    default => 1,
);

# This attribute has no effect
has 'PICS' => (
    is => 'rw',
    isa => 'Str',
    default => '',
);

has 'Status' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);

sub BUILD {
    my ( $self ) = @_;

    # Due to problem mentioned above in the builder methods, we are calling
    # these attributes to populate the values for the hash key to be available
    $self->Cookies;

    no warnings 'redefine';
    *TIEHANDLE = sub { $self };
    $self->{out} = $self->{BinaryRef} = \( $self->{Body} );
}

sub AddHeader {
    my ( $self, $name, $value ) = @_;
    $self->asp->c->response->header( $name => $value );
}

sub PRINT { my $self = shift; $self->Write( $_ ) for @_ }
sub PRINTF {
    my ( $self, $format, @list ) = @_;
    $self->Write( sprintf( $format, @list) );
}
*BinaryWrite = *Write;

sub AppendToLog {
    my ( $self, $message ) = @_;
    $self->asp->c->log->debug( $message );
}

sub WriteRef {
    my ( $self, $dataref ) = @_;
    $self->Write( $$dataref );
}

sub Clear {
    my ( $self ) = @_;
    $self->Body && $self->Body( $self->BodySubstr( 0, $self->_flushed_offset ) );
    $self->{out} = $self->{BinaryRef} = \( $self->{Body} );
    return;
}

sub Cookies {
    my ( $self, $name, @cookie ) = @_;

    if ( @cookie == 0 ) {
        return $self->_get_Cookies;
    } elsif ( @cookie == 1 ) {
        my $value = $cookie[0];
        return $self->_set_Cookie( $name => $value );
    } else {
        my ( $key, $value ) = @cookie;
        if ( my $existing = $self->_get_Cookie( $name ) ) {
            return $existing->{$key} = $value;
        } else {
            return $self->_set_Cookie( $name => { $key => $value } );
        }
    }
}

sub Debug {
    my ( $self, @args ) = @_;
    local $Data::Dumper::Maxdepth = 1;
    $self->AppendToLog( Dumper( \@args ) );
}

sub Flush {
    my ( $self ) = @_;
    $self->asp->GlobalASA->Script_OnFlush;
    $self->_flushed_offset( $self->BodyLength );
}

sub End {
    shift->Clear;
    die 'asp_end';
}

# TODO to implement or not to implement?
sub ErrorDocument {
    my ( $self, $code, $uri ) = @_;
    $self->asp->c->log->warn( "\$Reponse->ErrorDocument has not been implemented!" );
    return;
}

sub Include {
    my ( $self, $include, @args ) = @_;
    my $asp = $self->asp;
    my $c = $asp->c;

    my $compiled;
    if ( ref( $include ) && ref( $include ) eq 'SCALAR' ) {
        my $scriptref = $include;
        my $parsed_object = $asp->parse( $c, $scriptref );
        $compiled = {
            mtime => time(),
            perl => $parsed_object->{data},
        };
        my $caller = [ caller(1) ]->[3] || 'main';
        my $id = join( '', '__ASP_', $caller, 'x', $asp->_compile_checksum );
        my $subid = join( '', $asp->GlobalASA->package, '::', $id, 'xREF' );
        if ( $parsed_object->{is_perl}
            && ( my $code = $asp->compile( $c, $parsed_object->{data}, $subid ) ) ) {
            $compiled->{is_perl} = 1;
            $compiled->{code} = $code;
        } else {
            $compiled->{is_raw} = 1;
            $compiled->{code} = $parsed_object->{data};
        }
    } else {
        $compiled = $asp->compile_include( $c, $include );
    }

    my $code = $compiled->{code};

    # exit early for cached static file
    if ( $compiled->{is_raw} ) {
        $self->WriteRef( $code );
        return;
    }

    $asp->execute( $c, $code, @args );
}

sub Redirect {
    my ( $self, $url ) = @_;
    my $c = $self->asp->c;

    $c->response->redirect( $url );
    $c->detach;
}

sub TrapInclude {
    my ( $self, $include, @args ) = @_;

    my $saved = $self->Body;
    $self->Clear;

    local $self->{out} = local $self->{BinaryRef} = \( $self->{Body} );
    local *CatalystX::ASP::Response::Flush = sub {};

    $self->Include( $include, @args );
    my $trapped = $self->Body;

    $self->Body( $saved );

    return \$trapped;
}

__PACKAGE__->meta->make_immutable;
