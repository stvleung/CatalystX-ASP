package CatalystX::ASP::Compiler;

use Moose::Role;

use File::Slurp qw(read_file);
use Carp;

with 'CatalystX::ASP::Parser';

requires 'parse_file';

has '_compiled_includes' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
    traits => [ qw(Hash) ],
    handles => {
        _get_compiled_include => 'get',
        _add_compiled_include => 'set',
        _include_is_compiled => 'exists',
    },
);

has '_registered_includes' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
    traits => [ qw(Hash) ],
    handles => {
        _include_is_registered => 'exists',
        _add_registered_include => 'set',
    },
);

sub compile {
    my ( $self, $c, $scriptref, $subid ) = @_;

    my $package = $self->GlobalASA->package;
    $self->_undefine_sub( $subid );

    my $code = join( ' ;; ',
        "package $package;", # for no sub closure
        "no strict;",
        "sub $subid { ",
        "package $package;", # for sub closure
        $$scriptref,
        '}',
    );
    $code =~ /^(.*)$/s; # why?
    $code = $1;

    no warnings;
    local $SIG{__DIE__} = \&Carp::confess if $self->Debug;
    eval $code;
    if ( $@ ) {
        $c->error( "Error on compilation of $subid: $@" ); # don't throw error, so we can throw die later
        $self->_undefine_sub( $subid );
        return;
    } else {
        $self->register_include( $c, $scriptref );
        return $subid;
    }
}

sub compile_include {
    my ( $self, $c, $include ) = @_;

    my $file = $self->search_includes_dir( $include );

    return $self->compile_file( $c, $file );
}

sub compile_file {
    my ( $self, $c, $file ) = @_;

    my $id = $self->file_id( $file );
    my $subid = join( '', $self->GlobalASA->package, '::', $id, 'xINC' );

    return $self->_get_compiled_include( $subid ) if $self->_include_is_compiled( $subid );

    my $parsed_object = $self->parse_file( $c, $file );
    return unless $parsed_object;

    my %compiled_object = (
        mtime => time(),
        perl => $parsed_object->{data},
        file => $file,
    );

    if ( $parsed_object->{is_perl}
        && ( my $code = $self->compile( $c, $parsed_object->{data}, $subid ) ) ) {
        $compiled_object{is_perl} = 1;
        $compiled_object{code} = $code;
    } elsif ( $parsed_object->{is_raw} ) {
        $compiled_object{is_raw} = 1;
        $compiled_object{code} = $parsed_object->{data};
    } else {
        return;
    }

    # for a returned code ref, don't cache
    $self->_add_compiled_include( $subid => \%compiled_object )
        if ( $subid && ! $self->_parse_for_subs( $parsed_object->{data} ) );

    return \%compiled_object;
}

sub register_include {
    my ( $self, $c, $scriptref ) = @_;

    my $copy = $$scriptref;
    $copy =~ s/\$Response\-\>Include\([\'\"]([^\$]+?)[\'\"]/
        {
            my $include = $1;
            # prevent recursion
            unless( $self->_include_is_registered( $include ) ) {
                $self->_add_registered_include( $include => 1 );
                eval { $self->compile_include( $c, $include ); };
                $c->log->warn( "Register include $include with error: $@" ) if $@;
            }
            '';
        } /exsgi;
}

# This is how JCHAMAS gets a subroutined destroyed
sub _undefine_sub {
    my ( $self, $subid ) = @_;
    if ( my $code = \&{$subid} ) {
        undef( &$code );
    }
}

no Moose::Role;

1;
