#!perl
use strict;
use warnings FATAL => 'all';

use File::Temp qw( tempfile );
use File::Slurp qw( slurp );
use Digest::SHA;
use Test::More;

use App::Git::StrongHash::Objects;
use App::Git::StrongHash::ObjHasher;
use App::Git::StrongHash::Penderator;

use lib 't/lib';
use Local::TestUtil qw( testrepo_or_skip bin2hex );


sub main {
  my $testrepo = testrepo_or_skip();
  plan tests => 4;

  my $repo = App::Git::StrongHash::Objects->new($testrepo);
  $repo->add_tags->add_commits->add_trees;

  my $H = $repo->mkhasher(htype => [qw[ sha1 sha256 ]]);
  my $nobj = $H->{nci} + $H->{nblob} + 1 + 10; # + tags(anno) + trees
  is($H->{nci}, 8, "nci");
  is($H->{nblob}, 6, "nblob");
  is($H->{nobj}, $nobj, "nobj");

  my $df = $H->header_bin;
  $df .= join '', App::Git::StrongHash::Penderator->new
    ($repo->iter_ci($H),
     $repo->iter_tag($H),
     $repo->iter_tree($H),
     $repo->iter_blob($H))->collect;

  my $df_sha = Digest::SHA->new('sha1');
  $df_sha->add($df);
  $df_sha = $df_sha->hexdigest;
  is($df_sha,
     'moo', # GuruChecksChanges; or at least wonders whether change is expected
     'sha1(digestfile)')
    or diag bin2hex($df);

  my ($fh, $filename) = tempfile('08catfile.df.XXXXXX', TMPDIR => 1);
  $repo->mkdigesfile($fh, $H);
  close $fh or die "close $filename: $!";
  my $df2 = slurp($filename);
  my $df2_sha = Digest::SHA->new('sha1')->add($df2)->hexdigest;
  is($df2_sha, $df_sha, 'same when written to file');
  my %hdr = $H->header_bin2txt($df2);
  cmp_ok($hdr{nobj}, '==', $nobj, 'digestfile nobj');
  cmp_ok(length($df2), '==', $hdr{hdrlen} + $hdr{nobj} * $hdr{rowlen}, 'digestfile length');

  return 0;
}


exit main();
