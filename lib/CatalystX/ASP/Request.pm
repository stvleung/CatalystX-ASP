package CatalystX::ASP::Request;

use namespace::autoclean;
use Moose;

has 'asp' => (
    is => 'ro',
    isa => 'CatalystX::ASP',
    required => 1,
);

has 'FileUpload' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
    traits => [ qw(Hash) ],
    reader => '_get_FileUpload',
    writer => '_set_FileUpload',
    handles => {
        '_add_FileUpload' => 'set',
    },
);

# For some reason, for attributes that start with a capital letter, Moose seems
# to load the default value before the object is fully initialized. lazy => 1 is
# a workaround to build the defaults later
has 'Method' => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub { shift->asp->c->request->method },
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

    while ( my ( $field, $value ) = each %{$c->request->uploads} ) {
        my $c_upload = ref( $value ) eq 'ARRAY' ? $value->[0] : $value;
        my %upload = (
            ContentType => $c_upload->type,
            FileHandle => $c_upload->fh,
            BrowserFile => $c_upload->filename,
            TempFile => $c_upload->tempname,
        );
        $self->_add_FileUpload( $field => \%upload );
    }

    # Due to problem mentioned above in the builder methods, we are calling
    # these attributes to populate the values for the hash key to be available
    $self->Method;
    $self->TotalBytes;

    # Populate %ENV
    %ENV = ( %ENV, %{$c->request->env} );
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
    my $cookies = $self->asp->c->request->cookies;

    if ( $key ) {
        return $cookies->{$name}{value}{$key};
    } else {
        return $cookies->{$name};
    }
}

sub FileUpload {
    my ( $self, $form_field, $key ) = @_;
    $self->_get_FileUpload( $form_field )->{$key};
}

sub Form {
    my ( $self, $name ) = @_;
    my $params = $self->asp->c->request->body_parameters;
    return $name ? $params->{$name} : $params;
}

sub Params {
    my ( $self, $name ) = @_;
    my $params = $self->asp->c->request->parameters;
    return $name ? $params->{$name} : $params;
}

sub QueryString {
    my ( $self, $name ) = @_;
    my $params = $self->asp->c->request->query_parameters;
    return $name ? $params->{$name} : $params;
}

sub ServerVariables {
    my ( $self, $name ) = @_;
    return $name ? $ENV{$name} : \%ENV;
}

__PACKAGE__->meta->make_immutable;
