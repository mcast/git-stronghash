#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;
use Digest::SHA 'sha1_hex';
use YAML qw( Load );

use lib 't/lib';
use Local::TestUtil qw( testrepo_or_skip test_digestfile_name bin2hex cover_script );

use App::StrongHash::Git; # for the benefit of 00compile.t


sub main {
  my $testrepo = testrepo_or_skip();
  plan tests => 3;

  my ($blib) = grep { m{(^|/)blib/lib/?$} } @INC
    or die "Not running with blib/lib, so can't find built script; try 'prove -b'";
  my $bin = $blib;
  $bin =~ s{/lib$}{/script}
    or die "Can't make blib/script from $bin";

  cover_script();

  subtest all => sub {
    my $cmd = "cd $testrepo && $bin/git-stronghash-all -t sha1 -t sha256";
    my $digestfile = qx{$cmd};
    note explain { len => length($digestfile), cmd => $cmd };
    is(sha1_hex($digestfile),
       '09dd604c3f1c3668589fed4d2912d27635591478', # matches 08catfile.t
       'git-stronghash-all')
      or note bin2hex($digestfile);

    $cmd = "cd $testrepo && $bin/git-stronghash-all";
    my $df_256 = qx{$cmd};
    my $nobj = 25; # (cd t/testrepo/; git rev-list --all --objects)|sort -u|wc -l
    note explain { len => length($df_256), cmd => $cmd };
    is(length($df_256),
       length($digestfile)
       - 20 * $nobj # sha1_bin per obj
       - 5,         # "sha1," from header
       'default: sha256');

    $cmd = "t/_stdmerge $bin/git-stronghash-all junk";
    my $out = qx{$cmd};
    is($?, 0xFF00, 'junk argv: die');
    like($out, qr{^Syntax: }, 'junk argv: syntax message');
  };

  subtest dump => sub {
    my $df = test_digestfile_name('test-data-no-tags-b105de8d622dab99968653e591d717bc9d753eaf');
    my $cmd = "$bin/git-stronghash-dump $df";
    my $out = qx{$cmd};
    $out =~ s{^(.*\n)\.\.\.\n}{}s or die "YAML split fail";
    my ($top) = Load($1);
    is($top->{filename}, $df, 'b105de8d: filename');
    is_deeply($top->{header},
	      { magic => 'GitStrngHash',
		filev => 1,
		hdrlen => 36,
		nci => 2,
		nobj => 5,
		rowlen => 40,
		htype => [ gitsha1 => 'sha1' ],
		progv => '0.01',
		comment => 'n/c' },
	      'b105de8d: header')
      or note explain $top;
    my @out = split /\n/, $out;
    is_deeply([ split /\s+/, $out[0]],
	      [qw[ gitsha1 sha1 ]],
	      'b105de8d: digests coltitle');
    like($out[1], qr{^---+ +---+\s+$}, 'b105de8d: coltitle underline');
    is(scalar @out, $top->{header}{nobj} + 2, 'b105de8d:: digest rows');

    like(qx{t/_stdmerge $bin/git-stronghash-dump},
	 qr{^Syntax: \S+/git-stronghash-dump },
	 'some help text');
    like(qx{t/_stdmerge $bin/git-stronghash-dump /does/not/exist},
	 qr{^Read /does/not/exist: No such file or directory$},
	 'input not found');
  };

  subtest lookup => sub {
    my $df = test_digestfile_name('test-data-34570e3bd4ef302f7eefc5097d4471cdcec108b9'); # v1
    my $cmd = "$bin/git-stronghash-lookup --htype sha256 --files $df --check 03c56aa7f2f917ff2c24f88fd1bc52b0bab7aa17"; # d2/shopping.txt-h
    my $out = qx{$cmd};
    is($?, 0, "$cmd: exit");
    is($out, "e9f9db87cd76126f14bc24ee91fa22d8967b9867f2d6786cf61b74e91e6ee5bb\n", 'd2/shopping.txt (256)')
      or note "cmd=$cmd";;

    $cmd = "$bin/git-stronghash-lookup --htype sha256 --htype sha512 ".
      "--check e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 ".
      "--check f00c965d8307308469e537302baa73048488f162 ".
      "--files $df";
    $out = qx{$cmd};
    is($out, <<WANTOUT, 'mtgg ten (256, 512)') or note "cmd=$cmd";
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e
bf794518e35d7f1ce3a50b3058c4191bb9401e568fc645d77e10b0f404cf1f22 63ea70d6ef287c5a1db399ef6963bd02bb8d97d654b205feb824afde68abd0ef44e9801190ae3e874765dcad041773362ef469828d39f89dbf310b016742aa9c
WANTOUT

    like(qx{ $bin/git-stronghash-lookup --help 2>&1 },
	 qr{Specify objectids to check via --check flag}, 'help text');
    is($?, 0xFF00, ' exit');
    like(qx{ $bin/git-stronghash-lookup --spork 2>&1 },
	 qr{Specify objectids to check via --check flag}, 'help text (badopt)');
    is($?, 0xFF00, ' exit');
    like(qx{ $bin/git-stronghash-lookup --htype sha256 2>&1 },
	 qr{^Please specify lookup digestfiles with --files}, 'no files in');
    is($?, 0xFF00, ' exit');
    like(qx{ $bin/git-stronghash-lookup --files spork 2>&1 },
	 qr{^Please request hashtype\(s\)}, 'no htypes');
    is($?, 0xFF00, ' exit');
  };

  return 0;
}


exit main();
