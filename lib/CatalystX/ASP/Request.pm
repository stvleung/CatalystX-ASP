package CatalystX::ASP::Request;

use namespace::autoclean;
use Moose;

has 'asp' => (
    is => 'ro',
    isa => 'CatalystX::ASP',
    required => 1,
);

# For some reason, for attributes that start with a capital letter, Moose seems
# to load the default value before the object is fully initialized. lazy => 1 is
# a workaround to build the defaults later
has 'Cookies' => (
    is => 'ro',
    isa => 'HashRef',
    reader => '_get_Cookies',
    lazy => 1,
    default => sub {
        my ( $self ) = @_;
        my $c = $self->asp->c;
        my %cookies;
        for my $name ( keys %{$c->request->cookies} ) {
            $cookies{$name} = $c->request->cookies->{$name}{value};
        }
        return \%cookies;
    },
    traits => [ 'Hash' ],
    handles => {
        _get_Cookie => 'get',
    },
);

has 'FileUpload' => (
    is => 'ro',
    isa => 'HashRef',
    reader => '_get_FileUploads',
    lazy => 1,
    default => sub {
        my ( $self ) = @_;
        my %uploads;
        while ( my ( $field, $value ) = each %{$self->asp->c->request->uploads} ) {
            # Just assume the first upload field, because how Apache::ASP deals with
            # multiple uploads per-field is beyond me.
            my $upload = ref( $value ) eq 'ARRAY' ? $value->[0] : $value;
            $uploads{$field} = {
                ContentType => $upload->type,
                FileHandle => $upload->fh,
                BrowserFile => $upload->filename,
                TempFile => $upload->tempname,
            };
        }
        return \%uploads;
    },
    traits => [ 'Hash' ],
    handles => {
        _get_FileUpload => 'get',
    },
);

has 'Form' => (
    is => 'ro',
    isa => 'HashRef',
    reader => '_get_Form',
    lazy => 1,
    default => sub {
        my ( $self ) = @_;
        return {
            %{$self->asp->c->request->body_parameters},
            %{$self->asp->c->request->uploads},
        };
    },
    traits => [ 'Hash' ],
    handles => {
        _get_FormField => 'get',
    },
);

has 'Method' => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub { shift->asp->c->request->method },
);

has 'Params' => (
    is => 'ro',
    isa => 'HashRef',
    reader => '_get_Params',
    lazy => 1,
    default => sub { shift->asp->c->request->parameters },
    traits => [ 'Hash' ],
    handles => {
        _get_Param => 'get',
    },
);

has 'QueryString' => (
    is => 'ro',
    isa => 'HashRef',
    reader => '_get_QueryString',
    lazy => 1,
    default => sub { shift->asp->c->request->query_parameters },
    traits => [ 'Hash' ],
    handles => {
        _get_Query => 'get',
    },
);

has 'ServerVariables' => (
    is => 'ro',
    isa => 'HashRef',
    reader => '_get_ServerVariables',
    lazy => 1,
    default => sub {
        # Populate %ENV
        %ENV = ( %ENV, %{shift->asp->c->request->env} );
        return \%ENV;
    },
    traits => [ 'Hash' ],
    handles => {
        _get_ServerVariable => 'get',
    },
);

has 'TotalBytes' => (
    is => 'ro',
    isa => 'Int',
    lazy => 1,
    default => sub { shift->asp->c->request->content_length || 0 },
);

sub BUILD {
    my ( $self ) = @_;
    my $c = $self->asp->c;

    # Due to problem mentioned above in the builder methods, we are calling
    # these attributes to populate the values for the hash key to be available
    $self->Cookies;
    $self->FileUpload;
    $self->Form;
    $self->Method;
    $self->Params;
    $self->QueryString;
    $self->ServerVariables;
    $self->TotalBytes;
}

sub BinaryRead {
    my ( $self, $length ) = @_;
    my $c = $self->asp->c;
    my $body = $c->request->body;
    my @types = qw(application/x-www-form-urlencoded text/xml multipart/form-data);
    if ( grep { $c->request->content_type eq $_ } @types ) {
        my $buffer = '';
        $length ||= $c->request->content_length;
        $body->read( $buffer, $length );
        return $buffer;
    } else {
        return $body;
    }
}

# TODO: will not implement
sub ClientCertificate {
    my ( $self ) = @_;
    $self->asp->c->log->warn( "\$Request->ClientCertificate has not been implemented!" );
    return;
}

sub Cookies {
    my ( $self, $name, $key ) = @_;
    my $cookies = $self->_get_Cookies;

    if ( $name ) {
        if ( $key ) {
            return $self->_get_Cookie( $name )->{$key};
        } else {
            return $self->_get_Cookie( $name );
        }
    } else {
        return $self->_get_Cookies;
    }
}

sub FileUpload {
    my ( $self, $form_field, $key ) = @_;

    if ( $form_field ) {
        return $self->_get_FileUpload( $form_field )->{$key};
    } else {
        return $self->_get_FileUploads;
    }
}

sub Form {
    my ( $self, $name ) = @_;

    if ( $name ) {
        return $self->_get_FormField( $name );
    } else {
        return $self->_get_Form;
    }
}

sub Params {
    my ( $self, $name ) = @_;

    if ( $name ) {
        return $self->_get_Param( $name );
    } else {
        return $self->_get_Params;
    }
}

sub QueryString {
    my ( $self, $name ) = @_;

    if ( $name ) {
        return $self->_get_Query( $name );
    } else {
        return $self->_get_QueryString;
    }
}

sub ServerVariables {
    my ( $self, $name ) = @_;

    if ( $name ) {
        return $self->_get_ServerVariable( $name );
    } else {
        return $self->_get_ServerVariables;
    }
}

__PACKAGE__->meta->make_immutable;
