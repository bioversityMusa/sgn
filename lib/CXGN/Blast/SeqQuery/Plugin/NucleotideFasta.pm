
package CXGN::Blast::SeqQuery::Plugin::NucleotideFasta;

use Moose;


sub name { 
    return 'nucleotide fasta';
}

sub validate { 
    my $self = shift;
    my $c = shift;
    my $sequence = shift;

    eval { 
	my $string_fh = IO::String->new($sequence);
	my $io = Bio::SeqIO->new( -fh => $string_fh,
		       -format => 'fasta');
	while (my $seq = $io ->next_seq()) { 
	    if ($seq->seq() !~ /^[ATGCYWN \n\t]+$/i) { 
		die "Nucleotide sequence contains illegal characters: ".($seq->id);
	    }
	}
    };
    if ($@) { 
	return $@;
    }
    else { 
	return "OK";
    }

}

sub process { 
    my $self = shift;
    my $c = shift;
    my $sequence = shift;
    return $sequence;
}

1;