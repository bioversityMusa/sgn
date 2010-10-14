package SGN::Controller::Sequence;

=head1 NAME

SGN::Controller::Sequence - Catalyst controller for dealing with sequences

=cut

use Moose;
use namespace::autoclean;

use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';
our $c;

has schema => (
    is => 'rw',
    isa => 'Bio::Chado::Schema',
);

sub _build_schema {
    my ($self) = @_;
    return $c->dbic_schema('Bio::Chado::Schema','sgn_chado');
}


sub api_v1_sequence :Path('/api/v1/sequence') Args(1) {
    my ( $self, $c, $sequence_name ) = @_;
    $self->schema( $c->dbic_schema('Bio::Chado::Schema','sgn_chado') );
    $self->_view_sequence($c, 'name', $sequence_name);
}

sub _view_sequence {
    my ($self, $c, $key, $value) = @_;

    if ( $value =~ m/\.fasta$/ ) {
        $value =~ s/\.fasta$//;
        my $matching_features = $self->schema
                                    ->resultset('Sequence::Feature')
                                    ->search({ $key => $value });
        my $feature = $matching_features->next;
        $c->throw( message => "feature with $key = '$value' not found") unless $feature;
        $self->render_fasta($feature, $c);
    }
}

sub render_fasta {
    my ($self, $feature, $c) = @_;

    my $matching_features = $self->schema
                                ->resultset('Sequence::Feature')
                                ->search({ name => $feature->name });

    my $seq = Bio::PrimarySeq->new(
                    -id  => $feature->name,
                    -seq => $feature->residues,
                    );
    my $fasta;
    my $fastaio = IO::String->new($fasta);
    Bio::SeqIO->new( -format => 'fasta',
                     -fh     => $fastaio,
    )->write_seq( $seq );

    $c->res->content_type('text/plain');
    $c->res->status( 200 );
    $c->res->body( $fasta );
}

__PACKAGE__->meta->make_immutable;

1;

