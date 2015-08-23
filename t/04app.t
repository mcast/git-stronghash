#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;
use Digest::SHA 'sha1_hex';
use YAML qw( Load );

use lib 't/lib';
use Local::TestUtil qw( testrepo_or_skip bin2hex cover_script );


sub main {
  my $testrepo = testrepo_or_skip();
  plan tests => 2;

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
       'f50a640c06e2cb34aaf8fa99b57e7a2c1bdce664', # matches 08catfile.t
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
    my $df = 't/digestfile/v1/test-data-no-tags-b105de8d622dab99968653e591d717bc9d753eaf.stronghash';
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

  return 0;
}


exit main();
