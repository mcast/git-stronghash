#!perl
use strict;
use warnings FATAL => 'all';

use YAML qw( LoadFile Dump );
use Test::More;

use App::Git::StrongHash::Objects;

use lib 't/lib';
#use Local::TestUtil qw( mkiter tryerr plusNL ione t_nxt_wantarray );

my $GURU_CHECKED;
sub cmpobj {
  my ($wantname, $got, $morename) = @_;
  $morename = defined $morename ? " ($morename)" : '';
  ($GURU_CHECKED) = LoadFile("$0.yaml") unless $GURU_CHECKED;
  my $want = $GURU_CHECKED->{$wantname}
    or warn "Missing guru_checked entry '$wantname' in $0.yaml";
  my $ok = is_deeply($got, $want, $wantname.$morename);
  diag Dump({ got => $got, want => $want, wantname => $wantname.$morename })
    unless $ok;
  return $ok;
}

sub main {
  my $testrepo = $0;
  $testrepo =~ s{t/05objects\.t$}{test-data}
    or die "Can't make test-data/ on $testrepo";
  unless (-d $testrepo && -f "$testrepo/.git/config") {
    note " => # git clone $testrepo.bundle # will make it";
    plan skip_all => "test-data/ not expanded from bundle?";
  }

  plan tests => 4;

  my $repo;
  my $RST = sub { $repo = App::Git::StrongHash::Objects->new($testrepo) };

  $RST->();
  is((join '  ', $repo->_git),
     "git  --work-tree  test-data  --git-dir  test-data/.git",
     "git commandline prefix");

  $RST->();
  $repo->add_tags;
  cmpobj(add_tags => $repo);

  $RST->();
  $repo->add_commits;
  cmpobj(add_commits => $repo);

  $RST->();
  subtest add_trees => sub {
    plan tests => 6;
    my %field =
      (ci_tree => { b1ef447c50a6bb259e97b0e8153f1f5b58982531 => '25d1bf30ef7d61eef53b5bb4c2d61794316e1aeb' },
       tree => { '32823f581286f5dcff5ee3bce389e13eb7def3a8' => undef },
      );
    foreach my $f (qw( tag ci_tree tree blob )) {
      $repo->{$f} = $field{$f} ||= {};
    }
    $repo->add_tags->add_commits->add_trees;
    cmpobj(add_trees => $repo, "primed");
    while (my ($k, $v) = each %field) {
      cmp_ok(scalar keys %$v, '>', 0, "repo{$k} collection");
    }
    $RST->();
    $repo->add_tags->add_commits->add_trees;
    cmpobj(add_trees => $repo, "unprimed");
  };

  return 0;
}


exit main();
