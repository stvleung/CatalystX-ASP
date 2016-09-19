package CatalystX::ASP::GlobalASA;

use namespace::autoclean;
use Moose;
use MooseX::Types::Path::Tiny qw(Path);
use Path::Tiny;
use File::Slurp qw(read_file);

our @Routines = qw(
    Application_OnStart
    Application_OnEnd
    Session_OnStart
    Session_OnEnd
    Script_OnStart
    Script_OnEnd
    Script_OnParse
    Script_OnFlush
);

has 'asp' => (
    is => 'ro',
    isa => 'CatalystX::ASP',
    required => 1,
);

has 'filename' => (
    is => 'ro',
    isa => Path,
    default => sub { shift->asp->Global->child( 'global.asa' ) },
);

has 'package' => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
);

sub _build_package {
    my ( $self ) = @_;
    my $asp = $self->asp;
    my $id = $asp->file_id( $asp->Global, 1 );
    return $asp->GlobalPackage || "CatalystX::ASP::Compiles::$id";
}

sub BUILD {
    my ( $self ) = @_;
    my $asp = $self->asp;
    my $c = $asp->c;

    return unless $self->exists;

    my $package = $self->package;
    my $filename = $self->filename;
    my $global = $asp->Global;
    my $code = read_file( $filename );
    my $match_events = join '|', @Routines;
    $code =~ s/\<script[^>]*\>((.*)\s+sub\s+($match_events).*)\<\/script\>/$1/isg;
    $code = join( '',
        "\n#line 1 $filename\n",
        join( ' ;; ',
            "package $package;",
            'no strict;',
            'use vars qw(' . join( ' ', map { "\$$_" } @CatalystX::ASP::Objects ) . ');',
            "use lib qw($global);",
            $code,
            'sub exit { $main::Response->End(); }',
            "no lib qw($global);",
            '1;',
        )
    );
    $code =~ /^(.*)$/s; # why?
    $code = $1;

    no warnings 'redefine';
    eval $code;
    if ( $@ ) {
        $c->error( "Error on compilation of global.asa: $@" ); # don't throw error, so we can throw die later
    }
}

sub exists { shift->filename->exists }

sub execute_event {
    my ( $self, $event ) = @_;
    my $asp = $self->asp;
    $asp->execute( $asp->c, $event ) if "$self->package"->can( $event );
}

sub Application_OnStart {
    my ( $self ) = @_;
    $self->execute_event( join( '::', $self->package, 'Application_OnStart' ) );
}

sub Application_OnEnd {
    my ( $self ) = @_;
    $self->execute_event( join( '::', $self->package, 'Application_OnEnd' ) );
}

sub Session_OnStart {
    my ( $self ) = @_;
    $self->execute_event( join( '::', $self->package, 'Session_OnStart' ) );
}

sub Session_OnEnd {
    my ( $self ) = @_;
    $self->execute_event( join( '::', $self->package, 'Session_OnEnd' ) );
}

sub Script_OnStart {
    my ( $self ) = @_;
    $self->execute_event( join( '::', $self->package, 'Script_OnStart' ) );
}

sub Script_OnEnd {
    my ( $self ) = @_;
    $self->execute_event( join( '::', $self->package, 'Script_OnEnd' ) );
}

sub Script_OnParse {
    my ( $self ) = @_;
    $self->execute_event( join( '::', $self->package, 'Script_OnParse' ) );
}

sub Script_OnFlush {
    my ( $self ) = @_;
    $self->execute_event( join( '::', $self->package, 'Script_OnFlush' ) );
}


__PACKAGE__->meta->make_immutable;
