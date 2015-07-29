#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;

use App::Git::StrongHash;
use App::Git::StrongHash::Iterator;
use App::Git::StrongHash::Hashing;

use lib 't/lib';
#use Local::TestUtil qw( mkiter tryerr plusNL ione t_nxt_wantarray );


sub main {
  plan tests => 1;

  {
    local $TODO = 'write the app and script stub parts';
    fail("exercise App::Git::StrongHash");
  }

  return 0;
}


exit main();
