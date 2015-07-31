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
  my ($wantname, $got) = @_;
  ($GURU_CHECKED) = LoadFile("$0.yaml") unless $GURU_CHECKED;
  my $want = $GURU_CHECKED->{$wantname}
    or warn "Missing guru_checked entry '$wantname' in $0.yaml";
  my $ok = is_deeply($got, $want, $wantname);
  diag Dump({ got => $got, want => $want, wantname => $wantname }) unless $ok;
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

  plan tests => 2;

  my $repo;
  my $RST = sub { $repo = App::Git::StrongHash::Objects->new($testrepo) };

  $RST->();
  $repo->add_tags;
  cmpobj(add_tags => $repo);

  $RST->();
  $repo->add_commits;
  cmpobj(add_commits => $repo);

  return 0;
}


exit main();
