#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;

use App::Git::StrongHash::Objects;
use App::Git::StrongHash::TreeAdder;

use lib 't/lib';
use Local::TestUtil qw( tryerr );


sub main {
  plan tests => 1;

  subtest endfile => \&tt_endfile;

  return 0;
}

sub tt_endfile {
  my %tree;
  my %blob;
  my $O = App::Git::StrongHash::Objects->new('.');
  my $TA = App::Git::StrongHash::TreeAdder->new($O, \%tree, \%blob);

  my @warn;
  my $feed_tree = sub {
    local @{$TA}{qw{ tree obj }} = @_;
    local $SIG{__WARN__} = sub { push @warn, "@_" };
    return tryerr { $TA->endfile };
  };

  my $faketree = "100644 .gitignore\x00ABCDEFGHIJKLMNOPQRST100755 run-for-cover.sh\x00abcdefghijklmnopqrst40000 lib\x00....................";

  is_deeply($feed_tree->(fake => $faketree),
	    [ [qw[ 4142434445464748494a4b4c4d4e4f5051525354
		   6162636465666768696a6b6c6d6e6f7071727374 ]],
	      [qw[ 2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e ]] ],
	    'basic tree parse');

  $faketree =~ s/\.$//;
  like($feed_tree->(shortid => $faketree),
       qr{^ERR:Parse fail on tree shortid at offset 82 of 111 at \S*/TreeAdder\.pm line \d+\.\n\s+\S+::endfile\(\S+\) called at \Q$0 line },
       'shortid');

  $faketree .= '..';
  like($feed_tree->(longid => $faketree),
       qr{^ERR:Parse fail on tree longid at offset 112 of 113 at },
       'longid');

  $faketree =~ s{^\d+}{987654};
  like($feed_tree->(badmode => $faketree),
       qr{^ERR:Unknown object mode '987654 \.gitignore 4142\S+5354' in badmode at },
       'badmode');

  is("@warn", "", "warn(0)");
  @warn = ();

  is_deeply($feed_tree->(subrep => "160000 testrepo\x00::::::::::::::::::::040000 t\x00===================="),
	     [ [], [qw[ 3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d ]] ],
	    'subrepo');
  is("@warn",
     "TODO: Ignoring submodule '160000 commit 3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a testrepo'\n",
     "warn(1)");

  return;
}


exit main();
