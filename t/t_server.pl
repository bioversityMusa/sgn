#!/usr/bin/env perl
use strict;
use warnings;
use LWP::Simple;
use App::Prove;

use Pod::Usage;
use Getopt::Long;

use Catalyst::ScriptRunner;

use lib 'lib';
use SGN::Devel::MyDevLibs;

GetOptions(
    "carpalways" => \( my $carpalways = 0 ),
    );

require Carp::Always if $carpalways;

my @prove_args = @ARGV;
@prove_args = ( 't' ) unless @prove_args;

my $parallel = (grep /^-j\d*$/, @ARGV) ? 1 : 0;

if( my $server_pid = fork ) {

    # wait for the test server to start
    {
      local $SIG{CHLD} = sub {
          waitpid $server_pid, 0;
          die "\nTest server failed to start.  Aborting.\n";
      };
      sleep 1 until !kill(0, $server_pid) || get 'http://localhost:3003';
    }

    # set up env vars for prove and the tests
    $ENV{SGN_TEST_SERVER} = 'http://localhost:3003';
    if( $parallel ) {
        $ENV{SGN_PARALLEL_TESTING} = 1;
        $ENV{SGN_SKIP_LEAK_TEST}   = 1;
    }

    # now run the tests against it
    my $app = App::Prove->new;
    $app->process_args(
        '-lr',
        ( map { -I => $_ } @INC ),
        @prove_args
        );
    exit( $app->run ? 0 : 1 );

    END { kill 15, $server_pid if $server_pid }

} else {

    # server process
    $ENV{SGN_TEST_MODE} = 1;
    @ARGV = (
        -p => 3003,
        ( $parallel ? ('--fork') : () ),
     );
    Catalyst::ScriptRunner->run('SGN', 'Server');
    exit;

}

__END__

=head1 NAME

test_all.pl - start a dev server and run tests against it

=head1 SYNOPSIS

t/test_all.pl --carpalways -- -v -j5 t/mytest.t  t/mydiroftests/

=head1 OPTIONS

  --carpalways   Load Carp::Always in both the server and the test process
                 to force backtraces of all warnings and errors

=cut
