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

  if (defined (my $hps = $ENV{HARNESS_PERL_SWITCHES})) {
    # e.g. " -MDevel::Cover=-db,/mumble/git-stronghash/cover_db"
    my ($cover) = $hps =~ m{\s(-MDevel::Cover=\S+)(\s|$)}
      or die "Got HARNESS_PERL_SWITCHES='$hps' with no coverage options";
    die "PERL5OPT='$ENV{PERL5OPT}' already..?" if defined $ENV{PERL5OPT};
    $ENV{PERL5OPT} = $cover;
  }

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
