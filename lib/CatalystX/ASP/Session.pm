package CatalystX::ASP::Session;

use namespace::autoclean;
use Moose;
use parent 'Tie::Hash';

has 'asp' => (
    is => 'ro',
    isa => 'CatalystX::ASP',
    required => 1,
);

has '_is_new' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
    traits => [ qw(Bool) ],
    handles => {
        '_set_is_new' => 'set',
        '_unset_is_new' => 'unset'
    },
);

has '_session_key_index' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
    traits => [ qw(Counter) ],
    handles => {
        _inc_session_key_index => 'inc',
        _reset_session_key_index => 'reset',
    },
);

has '_session_keys' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
    traits => [ qw(Array) ],
    handles => {
        _session_keys_get => 'get',
    },
);

has 'CodePage' => (
    is => 'ro',
    isa => 'Item',
);

has 'LCID' => (
    is => 'ro',
    isa => 'item',
);

has 'SessionID' => (
    is => 'rw',
    isa => 'Str',
);

has 'Timeout' => (
    is => 'rw',
    isa => 'Int',
    default => 60,
);

sub Abandon {
    my ( $self ) = @_;
    my $asp = $self->asp;
    my $c = $asp->c;
    $asp->GlobalASA->Session_OnEnd;
    # By default, assume using Catalyst::Plugin::Session
    if ( $c->can( 'delete_session' ) ) {
        $c->delete_session( 'CatalystX::ASP::Sesssion::Abandon() called' )
    # Else assume using Catalyst::Plugin::iParadigms::Session
    } elsif ( $c->can( 'session_cache' ) ) {
        $c->session_cache->delete( $c->sessionid );
    }
}

# TODO: will not implement
sub Lock {
    my ( $self ) = @_;
    $self->asp->c->log->warn( "\$Session->Lock has not been implemented!" );
    return;
}

# TODO: will not implement
sub UnLock {
    my ( $self ) = @_;
    $self->asp->c->log->warn( "\$Session->UnLock has not been implemented!" );
    return;
}

sub TIEHASH {
    my ( $class, $self ) = @_;
    my $c = $self->asp->c;
    # By default, assume using Catalyst::Plugin::Session otherwise assume using
    # Catalyst::Plugin::iParadigms::Session
    my $session_is_valid = $c->can( 'session_is_valid' ) ? 'session_is_valid' : 'is_valid_session_id';
    unless ( $c->$session_is_valid( $c->sessionid ) ) {
        $self->_set_is_new;
        $self->SessionID( $c->sessionid );
    }
    return $self;
}

sub STORE {
    my ( $self, $key, $value ) = @_;
    return $value if $key =~ /asp|_is_new|_session_key/;
    $self->asp->c->session->{$key} = $value;
}

sub FETCH {
    my ( $self, $key ) = @_;
    for ( $key ) {
        if (/asp/) { return $self->asp }
        elsif (/_is_new/) { return $self->_is_new }
        elsif (/_session_key/) { return }
        else { return $self->asp->c->session->{$key} }
    }
}

sub FIRSTKEY {
    my ( $self ) = @_;
    $self->_session_keys( [ keys %{$self->asp->c->session} ] );
    $self->_reset_session_key_index;
    $self->NEXTKEY;
}

sub NEXTKEY {
    my ( $self, $lastkey ) = @_;
    my $key = $self->_session_keys_get( $self->_session_key_index );
    $self->_inc_session_key_index;
    if ( defined $key && $key =~ m/asp|_is_new|_session_key/ ) {
        return $self->NEXTKEY;
    } else {
        return $key;
    }
}

sub EXISTS {
    my ( $self, $key ) = @_;
    exists $self->asp->c->session->{$key};
}

sub DELETE {
    my ( $self, $key ) = @_;
    delete $self->asp->c->session->{$key};
}

sub CLEAR {
    my ( $self ) = @_;
    $self->DELETE( $_ ) for ( keys %{$self->asp->c->session} );
}

sub SCALAR {
    my ( $self ) = @_;
    scalar %{$self->asp->c->session};
}

__PACKAGE__->meta->make_immutable;
