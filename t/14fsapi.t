#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;

use App::StrongHash::FsPOSIX;

use lib 't/lib';
use Local::TestUtil qw( testrepo_or_skip tryerr );


sub main {
  my $testrepo = testrepo_or_skip();
  plan tests => 1;
  my $ASF = 'App::StrongHash::FsPOSIX';

  my $o = $ASF->new($testrepo);
  my @top = $o->scan;
  is_deeply(\@top,
	    [ map {"$testrepo/$_"}
	      qw[ .git/ 0hundred cdbdii d1/ d2/ mtgg ten ]],
	    'posix test-data top')
    or diag explain { top => \@top };

  return 0;
}


exit main();
