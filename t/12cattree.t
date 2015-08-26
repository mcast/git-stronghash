#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;

use App::Git::StrongHash::Objects;
use App::Git::StrongHash::TreeAdder;

use lib 't/lib';
use Local::TestUtil qw( tryerr );


sub main {
  plan tests => 1;

  my %tree;
  my %blob;
  my $O = App::Git::StrongHash::Objects->new('.');
  my $TA = App::Git::StrongHash::TreeAdder->new($O, \%tree, \%blob);

  my $faketree = "100644 .gitignore\x00ABCDEFGHIJKLMNOPQRST100755 run-for-cover.sh\x00abcdefghijklmnopqrst40000 lib\x00....................";

  is_deeply(do { local @{$TA}{qw{ tree obj }} = (fake => $faketree); $TA->endfile },
	    [ [qw[ 4142434445464748494a4b4c4d4e4f5051525354
		   6162636465666768696a6b6c6d6e6f7071727374 ]],
	      [qw[ 2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e ]] ],
	    'basic tree parse');

  return 0;
}


exit main();
