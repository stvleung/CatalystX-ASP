package CatalystX::ASP::Server;

use namespace::autoclean;
use Moose;
use HTML::Entities;
use URI;
use URI::Escape;

has 'asp' => (
    is => 'ro',
    isa => 'CatalystX::ASP',
    required => 1,
);

has 'ScriptTimeout' => (
    is => 'ro',
    isa => 'Str',
    default => 0,
);

sub Config {
    my ( $self, $setting ) = @_;

    return $self->asp->$setting
        if $self->asp->can( $setting );

    return;
}

# TODO: will not implement
sub CreateObject {
    my ( $self, $program_id ) = @_;
    $self->asp->c->log->warn( "\$Server->CreateObject has not been implemented!" );
    return;
}

sub Execute { shift->asp->Response->Include( @_ ) }

sub File {
    my $c = shift->asp->c;
    $c->path_to( 'root', $c->request->path );
}

# TODO: will not implement
sub GetLastError {
    my ( $self ) = @_;
    $self->asp->c->log->warn( "\$Server->GetLastError has not been implemented!" );
    return;
}

sub HTMLEncode {
    my ( $self, $string ) = @_;
    encode_entities( ref( $string ) ? $$string : $string );
}

sub MapInclude {
    my ( $self, $include ) = @_;
    $self->asp->search_includes_dir( $include );
}

sub MapPath {
    my ( $self, $url ) = @_;
    $self->asp->c->path_to( 'root', URI->new( $url )->path );
}

sub Mail {
    my ( $self, $mail, %smtp_args ) = @_;

    require Net::SMTP;
    my $smtp = Net::SMTP->new( $self->asp->MailHost, %smtp_args );

    my ( $from ) = split( /\s*,\s*/, ( $mail->{From} || '' ) ); # just the first one
    $smtp->mail( $from || $self->asp->MailFrom || return 0 );

    my @to;
    for my $field ( qw(To BCC CC) ) {
        my $receivers = $mail->{$field};
        next unless $receivers;
        # assume ref of $receivers is an ARRAY if it is
        my @receivers = ref $receivers ? @$receivers : ( split( /\s*,\s*/, $receivers ) );
        push @to, @receivers;
    }
    $smtp->to( @to ) || return;

    my $body = delete $mail->{Body};

    # assumes MIME-Version 1.0 for Content-Type header, according to RFC 1521
    # http://www.ietf.org/rfc/rfc1521.txt
    $mail->{'MIME-Version'} = '1.0' if $mail->{'Content-Type'} && ! $mail->{'MIME-Version'};

    my ( @data, %visited );
    # Though the list below are actually keys in $mail, this is to get them to
    # appear first, thought I'm not sure why it's needed
    for my $field ( 'Subject', 'From', 'Reply-To', 'Organization', 'To', keys %$mail ) {
        my $value = $mail->{$field};
        next unless $value;
        next if $visited{lc($field)}++;
        # assume ref of $value is an ARRAY if it is
        $value = join( ",", @$value ) if ref $value;
        $value =~ s/^[\n]*(.*?)[\n]*$/$1/;
        push @data, "$field: $value";
    }

    my $data = join( "\n", @data, '', $body );
    my $result;
    unless ( $result = $smtp->data( $data ) ) {
        $self->asp->c->error( $smtp->message );
    }

    $smtp->quit();
    return $result;
}

# TODO: will not implement
sub RegisterCleanup {
    my ( $self, $sub ) = @_;
    return;
}

sub Transfer { shift->asp->Response->Include( @_ ) }

sub URLEncode {
    my ( $self, $string ) = @_;
    uri_escape( $string );
}

sub URL {
    my ( $self, $url, $params ) = @_;
    my $uri = URI->new( $url )->query_form( $params );
    $uri->as_string;
}

# TODO: will not implement
sub XSLT {
    my ( $self, $xsl_dataref, $xml_dataref ) = @_;
    $self->asp->c->log->warn( "\$Server->XSLT has not been implemented!" );
    return;
}

__PACKAGE__->meta->make_immutable;
