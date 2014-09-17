
use strict;
use warnings;

use Test::More;

# ABSTRACT: Test basic performance

use Benchmark::CSV;
use Path::Tiny;

my $tdir = Path::Tiny->tempdir;

my $csv = $tdir->child('out.csv');

my $bench = Benchmark::CSV->new({   sample_size => 100, });
$bench->sample_size(10);

pass("Set sample_size did not fail");
done_testing;

