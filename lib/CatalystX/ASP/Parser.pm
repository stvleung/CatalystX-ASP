package CatalystX::ASP::Parser;

use Moose::Role;

use File::Slurp qw(read_file);
use HTML::Entities;

with 'CatalystX::ASP::Compiler';

requires 'compile_include';

sub _build_parsed_object {
    my ( $self, $scriptref, %opts ) = @_;

    $$scriptref = join( ';;',
        'no strict;',
        'use vars qw(' . join( ' ', map { "\$$_" } @CatalystX::ASP::Objects ) . ');',
        $opts{file} ? "\n#line 1 $opts{file}\n" : '',
        $$scriptref,
    ) unless $opts{is_raw};

    return { %opts, data => $scriptref };
}

sub parse {
    my ( $self, $c, $scriptref ) = @_;

    $self->GlobalASA->Script_OnParse;
    $scriptref = $self->_parse_ssi( $c, $scriptref );
    my $parsed_scriptref = $self->_parse_asp( $c, $scriptref );
    if ( $parsed_scriptref ) {
        return $self->_build_parsed_object( $parsed_scriptref, is_perl => 1 );
    } else {
        return $self->_build_parsed_object( $scriptref, is_raw => 1 );
    }
}

sub parse_file {
    my ( $self, $c, $file ) = @_;

    my $scriptref = read_file( $file, scalar_ref => 1 );

    $scriptref = $self->_parse_ssi( $c, $scriptref );
    my $parsed_scriptref = $self->_parse_asp( $c, $scriptref );
    # _parse_asp returns undef if not an ASP script
    if ( $parsed_scriptref ) {
        return $self->_build_parsed_object( $parsed_scriptref, is_perl => 1, file => $file );
    } else {
        return $self->_build_parsed_object( $scriptref, is_raw => 1, file => $file );
    }
}

# This parser processes and converts are SSI to call $Response->Include()
sub _parse_ssi {
    my ( $self, $c, $scriptref ) = @_;

    $self->GlobalASA->execute_event( 'Script_OnParse' ) if $self->GlobalASA->exists;

    my $data = '';
    my $file_line_number;
    my $is_code_block;
    while ( $$scriptref =~ s/^(.*?)\<!--\#include\s+file\s*=\s*\"?([^\s\"]*?)\"?(\s+args\s*=\s*\"?.*?)?\"?\s*--\>//so) {
        $data .= $1; # append the head
        my $include = $2;
        my $args;
        if ( $3 ) {
            $args = $3;
            $args =~ s/^\s+args\s*\=\s*\"?//sgo;
        }

        my $head_data = $1;
        if ( $head_data =~ s/.*\n\#line (\d+) [^\n]+\n(\%\>)?//s ) {
            $file_line_number = $1;
            $is_code_block = $2 ? 0 : 1;
        }
        $file_line_number += $head_data =~ s/\n//sg;
        $head_data =~ s/\<\%.*?\%\>//sg;
        $is_code_block += $head_data =~ s/\<\%//sg;
        $is_code_block -= $head_data =~ s/\%\>//sg;
        $is_code_block = $is_code_block > 0; # stray percents like height=100%> kinds of tags

        # global directory, as well as includes dirs
        $c->error( "Could not find $include in IncludesDir" )
            unless $self->search_includes_dir( $include );

        # because the script is literally different whether there
        # are includes or not, whether we are compiling includes
        # need to be part of the script identifier, so the global
        # caching does not return a script with different preferences.
        $args ||= '';
        $data .= "<% \$Response->Include('$include', $args); %>";

        # compile include now, so Loading() works for dynamic includes too
        $c->error( "Failed to compile $include" )
            unless $self->compile_include( $c, $include );
	}
	$data .= $$scriptref; # append what's left

    return \$data;
}

# Where the real ASP parsing happens. It's actually decently simple, just don't
# look at the Parse() from the original author.
sub _parse_asp {
    my ( $self, $c, $scriptref ) = @_;

    $$scriptref = $self->_parse_xml_subs( $c, $$scriptref ) if $self->XMLSubsMatch;

    # This is where we start to throw data back that lets the system render a
    # static file as is instead of executing it as a per subroutine.
    return unless $$scriptref =~ /\<\%.*?\%\>/s;

    $scriptref = \join( '', $$scriptref, '<%;;;%>' ); # always end with some perl code for parsing.

    my ( $script, @out, $perl_block, $last_perl_block );
    while ( $$scriptref =~ s/^(.*?)\<\%(.*?)\%\>//so ) {
        my ( $text, $perl ) = ( $1, $2 );
        my $is_perl_block = $perl !~ /^\s*\=(.*)$/so;

        # with some extra text parsing, we remove asp formatting from
        # influencing the generated html formatting, in particular
        # dealing with perl blocks and new lines
        if ( $text ) {
            # don't touch the white space, to preserve line numbers
            $text =~ s/\\/\\\\/gso;
            $text =~ s/\'/\\\'/gso;

            $last_perl_block = 0 if $last_perl_block;

            push @out, "\'$text\'";
        }

        if ( $perl ) {
            unless( $is_perl_block ) {
                # we have a scalar assignment here
                push( @out, "($1)" );
            } else {
                $last_perl_block = 1;
                if( @out ) {
                    # we pass by reference here with the idea that we are not
                    # copying the HTML twice this way.  This might be large
                    # saving on a typical site with rich HTML headers & footers
                    $script .= '$Response->WriteRef( \(' . join( '.', @out ) . ') );';
                    @out = ();
                }

                # allow old <% #comment %> style to still work, but we
                # need to insert a newline at the end of the comment for
                # it to still exist, with the lines now being sync'd up
                # if these old comments still exist, the perl script
                # will be off by one line from the asp script
                if ( $perl !~ /\n\s*$/so ) {
                    if ( $perl =~ /\#[^\n]*$/so ) {
                        $perl .= "\n";
                    }
                }

                # skip if the perl code is just a placeholder
                unless ( $perl eq ';;;' ) {
                    $script .= $perl . '; ';
                }
            }
        }
    }

    \$script;
}

# Helper method to process all the XML substitions in the script. Essentially
# translates xmlsubs to perl method calls, passing in arguments and html within
# each xmlsub tag
sub _parse_xml_subs {
    my ( $self, $c, $script ) = @_;

    $script = $self->_code_tag_encode( $script );

    my $xml_subs_match = $self->XMLSubsMatch;

    # Does a first pass to process xmlsubs with no content block within.
    # Eg. <xmlsub:method />
    # Why need to do first pass? I have no clue, need to ask JCHAMAS.
    $script =~ s@\<\s*($xml_subs_match)(\s+[^\>]*)?/\>
        @ {
            my ( $func, $args ) = ( $1, $2 );
            $args = $self->_code_tag_decode( $args );
            $func =~ s/\:+/\:\:/g;
            $func =~ s/\-/\_/g;
            if ( $args ) {
                $args =~ s/(\s*)([^\s]+?)(\s*)\=(\s*[^\s]+)/,$1'$2'$3\=\>$4/sg;
                $args =~ s/^(\s*),/$1/s;
            }
            $args ||= '';
            "<% $func({ $args }, ''); %>"
        } @sgex;

    while ( 1 ) {
        last unless $script =~ s@
            \<\s*($xml_subs_match)(\s+[^\>]*)?\>(?!.*?\<\s*\1[^\>]*\>)(.*?)\<\/\1\s*>
            @ {
                my( $func, $args, $text ) = ( $1, $2, $3 );
                $args = $self->_code_tag_decode( $args );
                $func =~ s/\:+/\:\:/g;
                # Parse and process args to convert into perl hash
                if ( $args ) {
                    $args =~ s/(\s*)([^\s]+?)(\s*)\=(\s*[^\s]+)/,$1'$2'$3\=\>$4/sg;
                    $args =~ s/^(\s*),/$1/s;
                }
                $args ||= '';
                $text = $self->_code_tag_decode( $text );

                if ( $text =~ m/\<\%|\<($xml_subs_match)/) {
                    # parse again, and control output buffer for this level
                    my $sub_scriptref = $self->_parse_asp( $c, \$text );
                    # Place the script inside a sub for compilation later
                    $text = join( ' ',
                        '&{sub {',
                        'my $saved = $Response->Body;',
                        '$Response->Clear;',
                        'local $Response->{out} = local $Response->{BinaryRef} = \( $Response->{Body} );',
                        'local *CatalystX::ASP::Response::Flush = sub {};',
                        $$sub_scriptref,
                        ';',
                        'my $trapped = $Response->Body;',
                        '$Response->Body( $saved );',
                        '$trapped;',
                        '} }'
                    );
                } else {
                    # raw text
                    $text =~ s/\\/\\\\/gso;
                    $text =~ s/\'/\\\'/gso;
                    $text = "'$text'";
                }

                "<% $func({ $args }, $text); %>"
            } @sgex;
    }

    return $self->_code_tag_decode( $script );
}

# This simply encodes any ASP tags into something that won't be processed anywhere
sub _code_tag_encode {
    my ( $self, $data ) = @_;

    if ( defined $data ) {
        $data =~ s@\<\%(.*?)\%\>
            @ { '[-AsP-[' . encode_entities( $1 ) . ']-AsP-]'; } @esgx;
    }
    return $data;
}

# This simply decodes what's been encoded above
sub _code_tag_decode {
    my ( $self, $data ) = @_;

    if ( defined $data ) {
        $data =~ s@\[\-AsP\-\[(.*?)\]\-AsP\-\]
            @ { '<%' . decode_entities( $1 ) . '%>'; } @esgx;
    }
    return $data;
}

# Searches the script for and subroutines, returns 1 or 0
sub _parse_for_subs {
    my ( $self, $scriptref ) = @_;

    return $$scriptref =~ /(^|\n)\s*sub\s+([^\s\{]+)\s*\{/;
}

no Moose::Role;

1;
