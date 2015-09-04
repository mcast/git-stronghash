#!perl
use strict;
use warnings FATAL => 'all';

our @unlinked;
BEGIN {
  # See unlinkage
  my $real_unlink;
  my $see_unlink = sub(@) {
    my @f = @_;
    die 'oops' if defined caller(500);
    # print STDERR  " # unlink happens(@f)\n";
    push @unlinked, grep { -f $_ } @f;
    return unlink @f;
  }
  ;
  no strict 'refs';
  no warnings 'redefine';
  *{'File::Temp::unlink'} = $see_unlink;
  # For some reason I don't understand, doing this at runtime just
  # before the cleanup is ineffective, the $see_unlink is not called.
  # Do it before loading File::Temp.
}

use File::Temp qw( tempfile cleanup );
use File::Slurp qw( slurp );
use Digest::SHA;
use Test::More;
use Test::MockObject;

use App::StrongHash::Git::Objects;
use App::StrongHash::ObjHasher;
use App::StrongHash::Listerator;
use App::StrongHash::Penderator;
use App::StrongHash::Git::CatFilerator;

use lib 't/lib';
use Local::TestUtil qw( testrepo_or_skip tryerr bin2hex t_nxt_wantarray );


sub main {
  my $testrepo = testrepo_or_skip();
  plan tests => 7;

  subtest "catfile" => sub {
    my @ids = qw( 25d1bf30ef7d61eef53b5bb4c2d61794316e1aeb
		  32823f581286f5dcff5ee3bce389e13eb7def3a8
		  96cc558853a03c5d901661af837fceb7a81f58f6 );
    my $R = App::StrongHash::Git::Objects->new($testrepo);
    my $H = App::StrongHash::ObjHasher->new
      (htype => [qw[ gitsha1 sha256 ]],
       nci => 0, nblob => 0, nobj => 0, blobbytes => 0);

    my $ids = App::StrongHash::Listerator->new(@ids);
    my $CF = App::StrongHash::Git::CatFilerator->new($R, $H, $ids);

    is($CF->{output_method}, 'output_hex', 'default output_method'); # wrong place
    t_nxt_wantarray($CF);

    my $tmp_fn = $CF->_ids_fn; # may go Away, but for now me must see cleanup
    ok(-f $tmp_fn, "tmpfile exists ($tmp_fn)");
    my ($got) = $CF->nxt;
    is($got, "gitsha1:25d1bf30ef7d61eef53b5bb4c2d61794316e1aeb SHA-256:e3c00fad34dcefaec0e34cdd96ee51ab405e3ded97277f294a17a5153d36bffe\n", 'tree0');
    {
      local $TODO = 'early _cleanup would be nice';
      ok(!-f $tmp_fn, "tmpfile gone (early)");
    }
    ($got) = $CF->nxt;
    is($got, "gitsha1:32823f581286f5dcff5ee3bce389e13eb7def3a8 SHA-256:cbd501dc604a1225934b26e4e5378fc670dd978e67c05f619f5717f502095ccf\n", 'tree1');

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
  subtest kidcrash => \&tt_kidcrash;
  subtest tmpclean=> \&tt_tmpclean;

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
  my $ids = App::StrongHash::Listerator->new(qw( a10000 ee00ff ));
  $L1 = __LINE__; my $CF = App::StrongHash::Git::CatFilerator->new
    ($mockrepo, $H, $ids, 'output_hex');
  $CF->start;
  my $tmp_fn = $CF->_ids_fn;
  is($CF->_ids_fn, $tmp_fn, "repeatable _ids_fn");
  like(tryerr { $CF->_ids_dump }, qr{^ERR:read gitsha1s: too late at }, "dump gitsha1s once only");
  like(tryerr { my @n = $CF->nxt; $n[0] },
       qr{^ERR:cat-file parse fail on 'foo\\ cat\\-file\\ \\-\\-batch' in 'echo },
       "already running / can't parse echo");
  $CF->_cleanup;
  $CF->_cleanup; # should not error
  is($CF->_ids_fn, undef, "_ids_fn cleared");
  like(tryerr { $CF->start }, # again
       qr{^ERR:read gitsha1s_fn: too late at }, "can't restart");
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
  my $R = App::StrongHash::Git::Objects->new($testrepo);
  my $H = App::StrongHash::ObjHasher->new
    (htype => [qw[ gitsha1 sha256 ]], nci => 2, nobj => 2, nblob => 0, blobbytes => 0);
  my $ids = App::StrongHash::Listerator->new
    (qw( 123456789abcdef0123456789abcdef012345678 96cc5588 )); # missing; seq 1 50
  my @w;
  local $SIG{__WARN__} = sub { push @w, "@_" };

  my $CF = App::StrongHash::Git::CatFilerator->new($R, $H, $ids, 'output_hex');
  my @n = $CF->nxt;
  is($n[0],
     "gitsha1:96cc558853a03c5d901661af837fceb7a81f58f6 SHA-256:02d36ee22aefffbb3eac4f90f703dd0be636851031144132b43af85384a2afcd\n",
     'sha256(seq 1 50)');
  is(scalar @w, 1, "one warning") or note explain { w => \@w };
  is(shift @w,
     "Expected gitsha1 123456789abcdef0123456789abcdef012345678, it is missing\n",
     "tell of missing");
  return;
}

sub tt_testrepo {
  my ($testrepo) = @_;
  my $repo = App::StrongHash::Git::Objects->new($testrepo);
  $repo->add_tags->add_commits->add_trees;

  my $H = $repo->mkhasher(htype => [qw[ gitsha1 sha1 sha256 ]]);
  my $nobj = $H->{nci} + $H->{nblob} + 1 + 10; # + tags(anno) + trees
  is($H->{nci}, 8, "nci");
  is($H->{nblob}, 6, "nblob");
  is($H->{nobj}, $nobj, "nobj");

  my $df = $H->header_bin;
  $df .= join '', App::StrongHash::Penderator->new
    ($repo->iter_ci(bin => $H),
     $repo->iter_tag(bin => $H),
     $repo->iter_tree(bin => $H),
     $repo->iter_blob(bin => $H))->collect;

  my $df_sha = Digest::SHA->new('sha1');
  $df_sha->add($df);
  $df_sha = $df_sha->hexdigest;
  is($df_sha,
     '09dd604c3f1c3668589fed4d2912d27635591478', # GuruChecksChanges; or at least wonders whether change is expected
     # f50a...e664: I checked first+last few bytes of (gitsha1,sha1,sha256) for first and last objects, they looked perfectly feasible
     # 09dd...1478: headerlength +=8, htypes starts gitsha1,
     'sha1(digestfile)')
    or diag bin2hex($df);

  my ($fh, $filename) = # unlink here
    tempfile('08catfile.df.XXXXXX', TMPDIR => 1, UNLINK => 1);
  $repo->mkdigesfile($fh, $H);
  close $fh or die "close $filename: $!";
  my $df2 = slurp($filename);
  unlink $filename;
  my $df2_sha = Digest::SHA->new('sha1')->add($df2)->hexdigest;
  is($df2_sha, $df_sha, 'same when written to file');
  my %hdr = $H->header_bin2txt($df2);
  cmp_ok($hdr{nobj}, '==', $nobj, 'digestfile nobj');
  cmp_ok(length($df2), '==', $hdr{hdrlen} + $hdr{nobj} * $hdr{rowlen}, 'digestfile length');

  return;
}

sub tt_kidcrash {
  my $testrepo = testrepo_or_skip();
  my $R = App::StrongHash::Git::Objects->new($testrepo)->add_commits;
  my $H = App::StrongHash::ObjHasher->new
    (htype => [qw[ gitsha1 sha256 ]], nci => 0, nobj => 0);

  # Run program which fails
  my $CF = App::StrongHash::Git::CatFilerator->new($R, $H, $R->iter_ci);
  $CF->{cmd} = [qw[ false ]];
  like(tryerr { my @n = $CF->nxt; $n[0] },
       qr{^ERR:command returned 1 in 'false'}, 'false');
  like(tryerr { my @n = $CF->nxt; $n[0] },
       qr{^ERR:command has finished in 'false'}, 'not false again');

  # Run program which doesn't exist, warnings to STDOUT
  $CF = App::StrongHash::Git::CatFilerator->new($R, $H, $R->iter_ci);
  $CF->{cmd} = [qw[ /does/not/exist ]];
  my $prog_dne = tryerr {
    local $SIG{__WARN__} =
      # warning of fail goes into parser, before exit(1)
      sub { print STDOUT "warn: @_" };
    my @n = $CF->nxt;
    $n[0];
  };
  my $prog_dne_re = qr{^ERR:cat-file parse fail on '(.*)' in '/does/not/exist'};
  like($prog_dne, $prog_dne_re, 'run /d/n/e parse junk');
  my ($run_warn) = # the text we wanted to see happen
    $prog_dne =~ $prog_dne_re;
  $run_warn =~ s{\\(.)}{$1}g; # un-quotemeta
  like($run_warn,
       qr{^warn: Can't exec "/does/not/exist": No such file or directory at \S*blib/lib/App/StrongHash/Piperator\.pm line \d+\.$},
       'run /d/n/e post-exec warn');
  like(tryerr { my @n = $CF->nxt; $n[0] },
       qr{^ERR:command returned 1 in '/does/not},
       'run /d/n/e exit code follows');
  like(tryerr { my @n = $CF->nxt; $n[0] },
       qr{^ERR:command has finished in '/does/not},
       'run /d/n/e refuse repeat');

  # Feed program from absent input file, warnings to STDOUT
  $CF = App::StrongHash::Git::CatFilerator->new($R, $H, $R->iter_ci);
  $CF->{gitsha1s_fn} = '/does/not/exist';
  my $input_dne = tryerr {
    local $SIG{__WARN__} = sub { print STDOUT "warn: @_" };
    my @n = $CF->nxt;
    $n[0];
  };
  $input_dne =~ s{\\(.)}{$1}g; # un-quotemeta
  like($input_dne,
       qr{^ERR:cat-file parse fail on 'warn: open /does/not/exist to STDIN: No such file or },
       'pipe from /d/n/e post-exec warn');
  like(tryerr { my @n = $CF->nxt; $n[0] },
       qr{^ERR:command returned 1 in 'git .* cat-file --batch'},
       'pipe from /d/n/e exit code follows');

  return;
}

sub tt_tmpclean {
  my $testrepo = testrepo_or_skip();
  my $R = App::StrongHash::Git::Objects->new($testrepo)->add_commits;
  my $H = App::StrongHash::ObjHasher->new
    (htype => [qw[ gitsha1 sha256 ]], nci => 0, nobj => 0);

  my $CF = App::StrongHash::Git::CatFilerator->new($R, $H, $R->iter_ci);
  my $cf1_fn = $CF->_ids_fn;
  ok(! $CF->started, 'cf1: file made, not started, DESTROYed');
  ok(-f $cf1_fn, "cf1: tmpfile here") or note "cf1_fn=$cf1_fn";
  undef $CF;
  ok(! -f $cf1_fn, "cf1: tmpfile gone") or note "cf1_fn=$cf1_fn";

  $CF = App::StrongHash::Git::CatFilerator->new($R, $H, $R->iter_ci);
  my $cf2_fn = $CF->_ids_fn;
  my @cf2_out = $CF->collect;
  cmp_ok(scalar @cf2_out, '>', 1, 'cf2: emptied');
  ok(! -f $cf2_fn, "cf2: tmpfile gone") or note "cf2_fn=$cf2_fn";

  # something to see unlinked
  @unlinked = ();		# probably already empty
  my ($fh, $filename) = tempfile('08catfile.tmpclean.XXXXXXXXXX', UNLINK => 1);
  close $fh;
  ok(-f $filename, 'canary here');
  cleanup();
  ok(! -f $filename, 'canary gone')
    or note explain { KEEP_ALL => $File::Temp::KEEP_ALL, filename => $filename };
  is_deeply(\@unlinked, [ $filename ], 'no other File::Temp to cleanup')
    or note explain { canary => $filename, unlinked => \@unlinked };
  # tmpfiles used by CatFilerator should have been cleaned already
}


exit main();
