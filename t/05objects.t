#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;

use App::Git::StrongHash::Objects;

use lib 't/lib';
#use Local::TestUtil qw( mkiter tryerr plusNL ione t_nxt_wantarray );


sub main {
  plan tests => 1;

  {
    local $TODO = 'test object listing';
    fail("not done");
  }

  return 0;
}


exit main();
