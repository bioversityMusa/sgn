
package SGN::Controller::StockBarcode;

use Moose;

use Bio::Chado::Schema::Result::Stock::Stock;
use CXGN::Stock::StockBarcode;

BEGIN { extends "Catalyst::Controller"; }

use CXGN::ZPL;


sub download_zdl_barcodes : Path('/barcode/stock/download') :Args(0) {
    my $self = shift;
    my $c = shift;

    my $stock_names = $c->req->param("stock_names");
    my $stock_names_file = $c->req->upload("stock_names_file");

    my $complete_list = $stock_names ."\n".$stock_names_file;

    $complete_list =~ s/\r//g; 
    
    my @names = split /\n/, $complete_list;

    my @not_found;
    my @found;
    my @labels;

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    
    foreach my $name (@names) { 

	# skip empty lines
	#
	if (!$name) { 
	    next; 
	}

	my $stock = $schema->resultset("Stock::Stock")->find( { name=>$name });

	if (!$stock) { 
	    push @not_found, $name;
	    next;
	}

	my $stock_id = $stock->stock_id();

	push @found, $name;

	# generate new label
	#
	my $label = CXGN::ZPL->new();
	$label->start_format();
	$label->barcode_code128($c->config->{identifier_prefix}.$stock_id);
	$label->end_format();
	push @labels, $label;
    }


    ####$c->res->content_type("text/download");

    my $dir = $c->tempfiles_subdir('zpl');
    my ($FH, $filename) = $c->tempfile(TEMPLATE=>"zpl/zpl-XXXXX", UNLINK=>0);

    foreach my $label (@labels) { 
	print STDERR "RENDERING LABEL ".$label->render()."\n";
	print $FH $label->render();
    }
    close($FH);

    $c->stash->{not_found} = \@not_found;
    $c->stash->{found} = \@found;
    $c->stash->{zpl_file} = $filename;
    $c->stash->{template} = '/barcode/stock_download_result.mas';
    
}

sub upload_barcode_output {
    my ($self, $c) = shift;
    my $upload = $c->req->upload('phenotype_file');
    my $contents = $upload->slurp;
    my $tempfile = $upload->tempname; #create a tempfile with the uploaded file
    my $sb = CXGN::Stock::Barcode->new( { schema=> $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado') });
    my $identifier_prefix = $c->config->{identifier_prefix};
    my $db_name = $c->config->{trait_ontology_db_name};
    $sb->parse($contents, $identifier_prefix, $db_name);
    my @errors = $sb->verify;
    $c->stash(
        template => '/stock/barcode/upload_confirm.mas',
        tempfile => $tempfile,
        errors   => \@errors,
        feedback_email => $c->config->{feedback_email},
        );

}

sub store_barcode_output  : Path('/barcode/stock/store') :Args(0) {
    my ($self, $c) = shift;
    my $contents = $c->req->param('tempfile');

    my $sb = CXGN::Stock::Barcode->new( { schema=> $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado') });
    my $identifier_prefix = $c->config->{identifier_prefix};
    my $db_name = $c->config->{trait_ontology_db_name};
    $sb->parse($contents, $identifier_prefix, $db_name);
    my $error = $sb->store;

    $c->stash(
        template => '/stock/barcode/confirm_store.mas',
        error    => $error,
        );

}

###
1;#
###