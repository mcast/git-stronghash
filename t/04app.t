#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;
use Digest::SHA 'sha1_hex';

use lib 't/lib';
use Local::TestUtil qw( testrepo_or_skip bin2hex );


sub main {
  my $testrepo = testrepo_or_skip();
  plan tests => 1;

  my ($blib) = grep { m{(^|/)blib/lib/?$} } @INC
    or die "Not running with blib/lib, so can't find built script; try 'prove -b'";
  my $bin = $blib;
  $bin =~ s{/lib$}{/script}
    or die "Can't make blib/script from $bin";

  my $cmd = "cd $testrepo && $bin/git-stronghash-all -t sha1 -t sha256";
  my $digestfile = qx{$cmd};
  note explain { len => length($digestfile), cmd => $cmd };
  is(sha1_hex($digestfile),
     'f50a640c06e2cb34aaf8fa99b57e7a2c1bdce664', # matches 08catfile.t
     'git-stronghash-all')
    or note bin2hex($digestfile);

  return 0;
}


exit main();
