
use strict;
use warnings;

use Test::More;
use SGN::Context;

my %maps = (
    agp  => "CXGN::Cview::Map::SGN::AGP",
    itag => "CXGN::Cview::Map::SGN::ITAG",
    9    => "CXGN::Cview::Map::SGN::Genetic",
    p9   => "CXGN::Cview::Map::SGN::Physical",
);
plan( tests => 1 + 2*(keys %maps));
use_ok('CXGN::Cview::MapFactory');

my $dbh = SGN::Context->new->dbc->dbh;
my $mf  = CXGN::Cview::MapFactory->new($dbh);



for my $k (keys %maps) {
    my $map = $mf->create( {map_id=>$k});

  SKIP: {
        skip 'map could not be created', 2 unless $map;
        is(ref($map), $maps{$k}, "map type test");
        is(scalar($map->get_chromosome_names()), 12, "chromosome count test");
    }
}

done_testing;
