package SGN::Controller::JavaScript;
use Moose;
use namespace::autoclean;

use File::Spec;

use Carp;
use Digest::MD5 'md5_hex';
use JSAN::ServerSide;
use List::MoreUtils qw/ uniq first_index /;
use Storable qw/ nfreeze /;

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';

__PACKAGE__->config(
    namespace => 'js',
   );


has '_package_defs' => (
    is => 'ro',
    lazy_build => 1,
   ); sub _build__package_defs {
       my $self = shift;

       my $cache = Cache::File->new(
           cache_root       => $self->_app->path_to( $self->_app->tempfiles_subdir('cache','js_packs') ),

           default_expires  => 'never',
           size_limit       => 1_000_000,
           removal_strategy => 'Cache::RemovalStrategy::LRU',
          );
   }

=head1 ACTIONS

=head2 js_package

Serve a minified, concatenated package of javascript, assembled and
stored on the previous request.

Args: package identifier (32-character hex)

=cut

sub js_package :Path('pack') :Args(1) {
    my ( $self, $c, $key ) = @_;

    # NOTE: you might think that we should cache the minified
    # javascript too, but it turns out to not be much faster!

    $c->stash->{js} = $self->_package_defs->thaw( $key );

    $c->log->debug(
         "serving JS pack $key = ("
        .(join ', ', @{ $c->stash->{js} || [] })
        .')'
       ) if $c->debug;

}

=head2 default

Serve a single (minified) javascript file from our js path.

=cut

sub default :Path {
    my ( $self, $c, @args ) = @_;

    $c->stash->{js} = [  File::Spec->catfile( @args ) ];
}

=head2 end

forwards to View::JavaScript

=cut

sub end :Private {
    my ( $self, $c ) = @_;

    # all of the actions in this controller will use View::Javascript
    # for rendering
    $c->forward('View::JavaScript');

    # handle missing JS with a 404
    if( @{ $c->error } == 1 && $c->error->[0] =~ /^Can't open '/ ) {
        warn $c->error->[0];

        $c->clear_errors;

        $c->res->status( 404 );
        $c->res->content_type( 'text/html' );

        $c->stash->{template} = "/site/error/404.mas";
        $c->stash->{message}  = "Javascript not found";
        $c->forward('View::Mason');
    }
}

=head2 insert_js_pack_html

Scans the current $c->res->body and inserts <script> includes for the
current set of javascript includes in the $c->stash->{pack_js}
arrayref.

Replaces comments like:

  <!-- INSERT_JS_PACK -->

with:

  <script src="(uri for js pack)" type="text/javascript">
  </script>

=cut


sub insert_js_pack_html :Private {
  my ( $self, $c ) = @_;

  my $js = $c->stash->{pack_js};
  return unless $js && @$js;

  my $b = $c->res->body;

  $c->log->debug("inserting js pack containing (@$js) into body of size ".length($b)) if $c->debug;

  my $url_cache;
  if( $b =~ s{<!-- \s* INSERT_JS_PACK \s* -->} {'<script src="'.($url_cache ||= $c->uri_for( $self->action_for_js_package( $js ))).qq|" type="text/javascript">\n</script>|}ex ) {
      $c->res->body( $b );
      delete $c->stash->{pack_js};
  }
}

=head1 REGULAR METHODS

=head2 action_for_js_package

  Usage: $controller->action_for_js_package([ 'sgn', 'jquery' ])
  Desc : get a list of (action,arguments) for getting a minified,
         concatenated set of javascript containing the given libraries.
  Args : arrayref of of JS libraries to include in the package
  Ret  : list of ( $action, @arguments )
  Side Effects: saves the list of js libs in a cache for subsequent
                requests
  Example:

      $c->uri_for( $c->controller('JavaScript')->action_for_js_package([ 'sgn', 'jquery' ]))

=cut

sub action_for_js_package {
    my ( $self, $files ) = @_;
    @_ == 2 && ref $files && ref $files eq 'ARRAY' && @$files
        or croak "action_for_js_package takes a single param, an arrayref of files";

    my @files = uniq @$files; #< do not sort, load order might be important
    for (@files) {
        s/\.js$//;
        s!\.!/!g;
    }

    # if prototype is present, move it to the front to prevent it
    # conflicting with jquery
    my $prototype_idx = first_index { /Prototype$/i } @files;
    if( $prototype_idx > -1 ) {
        my ($p) = splice @files, $prototype_idx, 1;
        unshift @files, $p;
    }


    # add in JSAN.use dependencies
    @files = $self->_resolve_jsan_dependencies( \@files );

    my $key = md5_hex( join '!!', @files );

   warn (
         "defining JS pack $key = ("
        .(join ', ', @files)
        .')'
       ) if $self->_app->debug;


    # record files for this particular package of JS
    if( $self->_package_defs->exists( $key ) ) {
        warn "key $key already exists in js_packs cache" if $self->_app->debug;
    } else {
        warn "key $key is new in js_packs cache" if $self->_app->debug;
        $self->_package_defs->freeze( $key => \@files );
    }

    return $self->action_for('js_package'),  $key;
}



########## helpers #########

sub _resolve_jsan_dependencies {
    my ( $self, $files ) = @_;

    # resolve JSAN dependencies of these files
    my $jsan = $self->new_jsan;
    for my $f (@$files) {
        $jsan->add( $f );
    }

    return map { s!^\/fake_prefix/!!; $_ } $jsan->uris;
}

has _jsan_params => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );
sub _build__jsan_params {
    my ( $self ) = @_;
    my $inc_path = $self->_app->config->{'js_include_path'};
    die "multi-dir js_include_path not yet supported" if @$inc_path > 1;
    my $js_dir = $inc_path->[0];
    -d $js_dir or die "configured js_include_path '$js_dir' does not exist!\n";
    return {
        js_dir     => "$js_dir",
        uri_prefix => '/fake_prefix',
    };
}
sub new_jsan {
    JSAN::ServerSide->new( %{ shift->_jsan_params } );
}


__PACKAGE__->meta->make_immutable;
1;
