#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;
use File::Slurp 'read_dir';
use List::Util 'shuffle';
use Time::HiRes qw( gettimeofday tv_interval );

use App::StrongHash::Git::Objects;

use lib 't/lib';
use Local::TestUtil qw( tryerr );


sub main {
  my ($repo, $rci, $robj) = find_big_repo(10_000, 100_000);
  plan skip_all => 'need a "large" sibling repository' unless $repo && -d $repo;
  plan tests => 3;
  note "using big repo = $repo";

  my $nci  = @$rci;
  my $nobj = @$robj;
  cmp_ok($nci,  '>',  10_000, "$repo: nci  =  $nci");
  cmp_ok($nobj, '>', 100_000, "$repo: nobj = $nobj");

  my $OL = App::StrongHash::Git::Objects->new($repo);

  my @t;
  my $addt = sub {
    my ($name) = @_;
    push @t, [ $name, [ gettimeofday() ] ];
    if (@t>1) {
      my $i = tv_interval($t[-2][1], $t[-1][1]);
      note sprintf(" t%10s %.3fs", "($name):", $i);
    }
  };

  {
    local $SIG{__WARN__} =
      sub { my $msg = "@_"; warn $msg unless $msg =~ /^TODO:/ };
    my $sec = 120;
    local $SIG{ALRM} =
      sub { die "Timeout (${sec}sec) scanning $repo" };
    alarm($sec);
    $addt->('start');
    foreach my $mth (qw( add_tags add_commits add_trees )) {
      $OL->$mth;
      $addt->($mth);
    }
    alarm(0);
  }

  local $TODO = 'break up objects into 64k units';
  ok(0);
#  ok($OL->need_split, 'bigrepo need_split');

  return 0;
}


exit main();


sub find_big_repo {
  my ($min_ci, $min_obj) = @_;

  # large git repos we might peek
  my $parent = '..';
  my @poss = grep { -d "$parent/$_/.git" } read_dir($parent);

  # don't be nosy
  my %whitelist;
  @whitelist{qw{ rust irods linux homebrew }} = ();
  @poss = grep { exists $whitelist{$_} } @poss;
  @poss = shuffle @poss;

  foreach my $r (map {"$parent/$_"} @poss) {
    my @ci = qx{ cd $r && git rev-list --all };
    next unless @ci > $min_ci;
    my @obj = qx{ cd $r && git rev-list --all --objects };
    next unless @obj > $min_obj;
    return ($r, \@ci, \@obj);
  }
  return ();
}
