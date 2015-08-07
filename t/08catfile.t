#!perl
use strict;
use warnings FATAL => 'all';

use File::Temp qw( tempfile );
use File::Slurp qw( slurp );
use Digest::SHA;
use Test::More;
use Test::MockObject;

use App::Git::StrongHash::Objects;
use App::Git::StrongHash::ObjHasher;
use App::Git::StrongHash::Listerator;
use App::Git::StrongHash::Penderator;

use lib 't/lib';
use Local::TestUtil qw( testrepo_or_skip bin2hex );


sub main {
  my $testrepo = testrepo_or_skip();
  plan tests => 2;

  subtest "catfile" => sub {
    my @ids = qw( 25d1bf30ef7d61eef53b5bb4c2d61794316e1aeb
		  32823f581286f5dcff5ee3bce389e13eb7def3a8
		  96cc558853a03c5d901661af837fceb7a81f58f6 );
    my $R = App::Git::StrongHash::Objects->new($testrepo);
    my $H = App::Git::StrongHash::ObjHasher->new
      (htype => [qw[ sha256 ]],
       nci => 0, nblob => 0, nobj => 0, blobbytes => 0);

    my $ids = App::Git::StrongHash::Listerator->new(@ids);
    my $CF = App::Git::StrongHash::CatFilerator->new($R, $H, $ids, 'output_hex');

    my ($got) = $CF->nxt;
    is($got, "objid:25d1bf30ef7d61eef53b5bb4c2d61794316e1aeb SHA-256:e3c00fad34dcefaec0e34cdd96ee51ab405e3ded97277f294a17a5153d36bffe\n", 'tree0');
    ($got) = $CF->nxt;
    is($got, "objid:32823f581286f5dcff5ee3bce389e13eb7def3a8 SHA-256:cbd501dc604a1225934b26e4e5378fc670dd978e67c05f619f5717f502095ccf\n", 'tree1');

    $CF->{chunk} = 50;
    $H = $CF->{hasher} = Test::MockObject->new;
    my @chunk;
    my @newfile;
    $H->mock(newfile => sub { shift; push @newfile, @_ });
    $H->mock(add     => sub { shift; push @chunk,   @_ });
    $H->mock(output_hex => sub { 0xDECAFBAD });

    ($got) = $CF->nxt;
    is($got, 0xDECAFBAD, 'blob is mocked');
    is("@newfile", "blob 141 96cc558853a03c5d901661af837fceb7a81f58f6", "newfile");
    my @chunklen = map { length($_) } @chunk;
    is("@chunklen", "50 50 41", "chunklen");
    is((join '', @chunk), (join "\n", (1..50),''), "chunks");

    ($got) = $CF->nxt;
    is($got, undef, "eof");
  };

  subtest "test-data/" => sub { tt_testrepo($testrepo) };

  return 0;
}


sub tt_testrepo {
  my ($testrepo) = @_;
  my $repo = App::Git::StrongHash::Objects->new($testrepo);
  $repo->add_tags->add_commits->add_trees;

  my $H = $repo->mkhasher(htype => [qw[ sha1 sha256 ]]);
  my $nobj = $H->{nci} + $H->{nblob} + 1 + 10; # + tags(anno) + trees
  is($H->{nci}, 8, "nci");
  is($H->{nblob}, 6, "nblob");
  is($H->{nobj}, $nobj, "nobj");

  my $df = $H->header_bin;
  $df .= join '', App::Git::StrongHash::Penderator->new
    ($repo->iter_ci(bin => $H),
     $repo->iter_tag(bin => $H),
     $repo->iter_tree(bin => $H),
     $repo->iter_blob(bin => $H))->collect;

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

  return;
}


exit main();
