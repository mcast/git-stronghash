#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;
use Digest::SHA 'sha1_hex';

use lib 't/lib';
use Local::TestUtil qw( testrepo_or_skip bin2hex cover_script );


sub main {
  my $testrepo = testrepo_or_skip();
  plan tests => 4;

  my ($blib) = grep { m{(^|/)blib/lib/?$} } @INC
    or die "Not running with blib/lib, so can't find built script; try 'prove -b'";
  my $bin = $blib;
  $bin =~ s{/lib$}{/script}
    or die "Can't make blib/script from $bin";

  cover_script();

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

  return 0;
}


exit main();
