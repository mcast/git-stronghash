#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;

use App::Git::StrongHash::DigestReader;

use lib 't/lib';
use Local::TestUtil qw( testrepo_or_skip tryerr hex2bin bin2hex fh_on );


sub main {
  my $testrepo = testrepo_or_skip();

  plan tests => 1;
  local $TODO = 'what next?'; fail('hmmm');

  return 0;
}


exit main();
