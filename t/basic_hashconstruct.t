
use strict;
use warnings;

use Test::More;

# ABSTRACT: Test basic performance

use Benchmark::CSV;
use Path::Tiny;

my $tdir = Path::Tiny->tempdir;

my $csv = $tdir->child('out.csv');

local $@;
ok(
  eval {
    my $bench = Benchmark::CSV->new(
      {
        sample_size => 100,
        output      => $csv,
      }
    );
    1;
  },
  "Construct with a hashref"
) or diag $@;

done_testing;

