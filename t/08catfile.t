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
use App::Git::StrongHash::CatFilerator;

use lib 't/lib';
use Local::TestUtil qw( testrepo_or_skip tryerr bin2hex t_nxt_wantarray );


sub main {
  my $testrepo = testrepo_or_skip();
  plan tests => 5;

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

    t_nxt_wantarray($CF);

    my $tmp_fn = $CF->_ids_fn; # may go Away, but for now me must see cleanup
    ok(-f $tmp_fn, "tmpfile exists ($tmp_fn)");
    my ($got) = $CF->nxt;
    is($got, "objid:25d1bf30ef7d61eef53b5bb4c2d61794316e1aeb SHA-256:e3c00fad34dcefaec0e34cdd96ee51ab405e3ded97277f294a17a5153d36bffe\n", 'tree0');
    {
      local $TODO = 'early _cleanup would be nice';
      ok(!-f $tmp_fn, "tmpfile gone (early)");
    }
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
    ok(!-f $tmp_fn, "tmpfile gone (eof)"); # TODO: move this up, we could _cleanup after first object returns
  };

  subtest breakage => \&tt_breakage;
  subtest missing  => \&tt_missing;
  subtest "test-data/" => sub { tt_testrepo($testrepo) };

  local $TODO = 'L8R';
  fail('check zombie acculumation');

  return 0;
}


sub tt_breakage {
  my @w;
  local $SIG{__WARN__} = sub { push @w, "@_" };

  my ($L1, $L2);
  my $mockrepo = Test::MockObject->new;
  $mockrepo->mock(_git => sub { qw( echo foo ) });
  my $H = Test::MockObject->new;
  my $ids = App::Git::StrongHash::Listerator->new(qw( a10000 ee00ff ));
  $L1 = __LINE__; my $CF = App::Git::StrongHash::CatFilerator->new
    ($mockrepo, $H, $ids, 'output_hex');
  my $tmp_fn = $CF->_ids_fn;
  is($CF->_ids_fn, $tmp_fn, "repeatable _ids_fn");
  like(tryerr { $CF->_ids_dump }, qr{^ERR:read objids: too late at }, "dump objids once only");
  $CF->_cleanup;
  $CF->_cleanup; # should not error
  is($CF->_ids_fn, undef, "_ids_fn cleared");
  like(tryerr { my @n = $CF->nxt; $n[0] },
       qr{^ERR:cat-file parse fail on 'foo\\ cat\\-file\\ \\-\\-batch' in 'echo },
       "already running / can't parse echo");
  like(tryerr { $CF->_start }, # (again - it was called in new)
       qr{^ERR:read objids_fn: too late at }, "can't restart");
  is(scalar @w, 0, "no warning yet");
  undef $CF; $L2 = __LINE__;
  is(scalar @w, 1, "one warning") or note explain { w => \@w };
  is(shift @w,
     "[w] DESTROY before close on 'echo foo cat-file --batch' from $0:$L1 at $0 line $L2.\n",
     "close fail warn");
  return;
}

sub tt_missing {
  my $testrepo = testrepo_or_skip();
  my $R = App::Git::StrongHash::Objects->new($testrepo);
  my $H = App::Git::StrongHash::ObjHasher->new
    (htype => [qw[ sha256 ]], nci => 2, nobj => 2, nblob => 0, blobbytes => 0);
  my $ids = App::Git::StrongHash::Listerator->new
    (qw( 123456789abcdef0123456789abcdef012345678 96cc5588 )); # missing; seq 1 50
  my @w;
  local $SIG{__WARN__} = sub { push @w, "@_" };

  my $CF = App::Git::StrongHash::CatFilerator->new($R, $H, $ids, 'output_hex');
  my @n = $CF->nxt;
  is($n[0],
     "objid:96cc558853a03c5d901661af837fceb7a81f58f6 SHA-256:02d36ee22aefffbb3eac4f90f703dd0be636851031144132b43af85384a2afcd\n",
     'sha256(seq 1 50)');
  is(scalar @w, 1, "one warning") or note explain { w => \@w };
  is(shift @w,
     "Expected objectid 123456789abcdef0123456789abcdef012345678, it is missing\n",
     "tell of missing");
  return;
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
     'f50a640c06e2cb34aaf8fa99b57e7a2c1bdce664', # GuruChecksChanges; or at least wonders whether change is expected
     # f50a...e664: I checked first+last few bytes of (objid,sha1,sha256) for first and last objects, they looked perfectly feasible
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
