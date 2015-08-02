#!perl
use strict;
use warnings FATAL => 'all';

use List::Util qw( sum );
use YAML qw( LoadFile Dump );
use Test::More;

use App::Git::StrongHash;
use App::Git::StrongHash::ObjHasher;
use App::Git::StrongHash::Objects;

use lib 't/lib';
#use Local::TestUtil qw( mkiter tryerr plusNL ione t_nxt_wantarray );

sub main {
  my $OH = 'App::Git::StrongHash::ObjHasher';
  plan tests => 2;

  my @HT = $OH->htypes;
  my $H = $OH->new(htype => \@HT, nci => 1, nobj => 1, nblob => 0, blobbytes => 0);
  $H->newfile(commit => 200, '0123456789abcdef0123456789abcdef01234567');
  cmp_ok(length($H->output_bin), '==', $H->rowlen, "length(output_bin) == rowlen");
  note $H->rowlen, " byte";

  is(App::Git::StrongHash->VERSION, '0.01'); # XXX: compare to header

  return 0;
}


exit main();
