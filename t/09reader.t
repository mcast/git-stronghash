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

  like(tryerr { App::Git::StrongHash::DigestReader->new(testdata => 'filename') },
       qr{^ERR:Filehandle filename should be in binmode}, 'wantbinmode');

  return 0;
}


exit main();
