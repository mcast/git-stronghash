#!perl
use strict;
use warnings FATAL => 'all';

use List::Util qw( sum );
use YAML qw( LoadFile Dump );
use Test::More;

use App::Git::StrongHash::Objects;

use lib 't/lib';
use Local::TestUtil qw( testrepo_or_skip );

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
  my $testrepo = testrepo_or_skip();
  my $testrepo_notags = testrepo_or_skip("-no-tags");
  plan tests => 5;

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
    plan tests => 12;
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

    is_deeply([ $repo->iter_ci->collect ],
	      [qw[
    34570e3bd4ef302f7eefc5097d4471cdcec108b9
    4ef2c9401ce4066a75dbe3e83eea2eace5920c37
    5d88f523fa75b55dc9b6c71bf1ee2fba8a32c0a5
    9385c9345d9426f1aba91302dc1f34348a4fec96
    b1ef447c50a6bb259e97b0e8153f1f5b58982531
    d537baf133bf25d04c0b0711341f59f04119b5e7
    f40b4bd2fd4373df3c7b4455c36786011a717460
    f81423b69ec303d11489e1c34a99d58f3c93846a
		]], "iter_ci");

    is_deeply([ $repo->iter_tag->collect ],
	      [qw[
    d9101db5d2c6d87f92605709f2e923cd269affec
		]], "iter_tag (exclude non-annotated)");

    is_deeply([ $repo->iter_tree->collect ],
	      [qw[
    18860e203b47f19b3126c50f6dfb91c2ae97a40d
    25d1bf30ef7d61eef53b5bb4c2d61794316e1aeb
    32823f581286f5dcff5ee3bce389e13eb7def3a8
    4b825dc642cb6eb9a060e54bf8d69288fbee4904
    5c1e1d7e049f5201eff7c3ca43c405f38564b949
    89a7d23f944d8f49e3fdbf3859de49423841d581
    8f0cc2158b0e9bf5a413c3841b2c7f7705bf2163
    ae5349e79d17a1d80b07e621441d06fe4907707a
    ec948845a4a83cee6a38d16b757c14958d9dec22
    f6656e1d2866d951c969141fa7afe848d9ed4a79
		]], "iter_tree");

    is_deeply([ $repo->iter_blob->collect ],
	      [qw[
    03c56aa7f2f917ff2c24f88fd1bc52b0bab7aa17
    4029c34c1729940c8e71938fbcd2c787f0081ffe
    507bc9769db563824b71e765f8fa59de18a49215
    96cc558853a03c5d901661af837fceb7a81f58f6
    e69de29bb2d1d6434b8b29ae775ad8c2e48c5391
    f00c965d8307308469e537302baa73048488f162
		]], "iter_blob");

    my @blobsize = qw( 12 400 9 141 0 21 );
    my ($want_num, $want_tot) = (scalar @blobsize, sum(@blobsize));
    is(scalar $repo->blobtotal, $want_tot, "blobtotal (scalar)");
    is_deeply([ $repo->blobtotal ], [ $want_tot, $want_num ], "blobtotal (list)");
  };

  subtest no_tags => sub {
    $repo = App::Git::StrongHash::Objects->new($testrepo_notags);
    $repo->add_tags;
    is_deeply([ $repo->iter_tag->collect ],
              [], "iter_tag");
    is_deeply([ $repo->iter_ci->collect ],
              [], "iter_ci (from tags)");
    $repo->add_commits->add_trees;
    is_deeply([ $repo->iter_ci->collect ],
              [qw[
    b105de8d622dab99968653e591d717bc9d753eaf
    c01bc611289464a647771cc6497df9e1daeaf981
                ]], "iter_ci");
  };

  return 0;
}


exit main();
