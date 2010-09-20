package SGN;
use Moose;
use namespace::autoclean;

use SGN::Exception;

use Catalyst::Runtime 5.80;
use Catalyst qw/
     -Debug
     ConfigLoader
     Static::Simple
     ErrorCatcher
     StackTrace

     +SGN::Role::Site::Config
     +SGN::Role::Site::DBConnector
     +SGN::Role::Site::DBIC
     +SGN::Role::Site::Exceptions
     +SGN::Role::Site::Files
     +SGN::Role::Site::Mason
     +SGN::Role::Site::SiteFeatures
 /;

extends 'Catalyst';

# on startup, do some dynamic configuration
after 'setup_finalize' => sub {
    my $self = shift;

    $ENV{PROJECT_NAME} = $self->config->{name};

    # all files written by web server should be group-writable
    umask 000002;

    # update the symlinks used to serve static files
    $self->_update_static_symlinks;

    ###  for production servers
    if( $self->config->{production_server} ) {

        # enable error email sending
        $self->config->{'Plugin::ErrorCatcher'}{'emit_module'} = 'Catalyst::Plugin::ErrorCatcher::Email';

    }
};


__PACKAGE__->setup;



sub _update_static_symlinks {
    my $self = shift;

    # symlink the static_datasets and
    # static_content in the root dir so that
    # Catalyst::Plugin::Static::Simple can serve them.  in production,
    # these will be served directly by Apache

    # make symlinks for static_content and static_datasets
    my @links =
        map [ $self->config->{$_.'_path'} =>
               $self->path_to( $self->config->{root}, $self->config->{$_.'_url'} )
            ],
        qw( static_content static_datasets );

    for my $link (@links) {
        if( $self->debug ) {
            my $l1_rel = $link->[1]->relative( $self->path_to );
            $self->log->debug("symlinking static dir '$link->[0]' -> '$l1_rel'") if $self->debug;
        }
        unlink $link->[1];
        symlink( $link->[0], $link->[1] )
            or die "$! symlinking $link->[0] => $link->[1]";
    }
}

=head1 NAME

SGN - Catalyst-based application to run the SGN website.

=head1 SYNOPSIS

    script/sgn_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<SGN::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Robert Buels,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
