#!perl
use strict;
use warnings FATAL => 'all';

use File::Slurp 'slurp';
use Test::More;
use Cwd 'abs_path';


sub main {
  plan tests => 3;

  my @modfn = split /\n/, slurp("$0.txt");
  @modfn = grep { ! /^#/ } @modfn;

  my @mod = map { my $m = $_; $m =~ s{\.pm$}{}; $m =~ s{/}{::}g; $m } @modfn;

  # FATAL=>all doesn't catch "Possible attempt to separate words with commas" ?
  $SIG{__WARN__} = sub {
    my ($msg) = @_;
    fail('warning');
    note("Warning: $msg");
    return;
  };

  subtest "All load" => sub {
    plan tests => 0+@modfn;
    foreach my $m (@mod) {
      is((eval "require $m; 'ok'" || "ERR:$@"), 'ok', "require $m");
    }
  }
    or BAIL_OUT("Compile error");

  my %seenmod; # pkg => fn
  while (my ($modfn, $path) = each %INC) {
    next unless $modfn =~ m{^App/Git/StrongHash};
    $modfn =~ s{\.pm$}{};
    $modfn =~ s{/}{::}g;
    $seenmod{$modfn} = $path;
  }

  my $base = $0;
  $base =~ s{(^|/)t/[^/]+$}{} or die "Base from $0 ?";
  $base = abs_path($base);
  my @not_ours = grep { not m{^\Q$base\E/b?lib/} } values %seenmod;
  is("@not_ours", "", "our modules, but loaded from outside our tree")
    or note explain { first_bad => $not_ours[0], want_pfx => "$base/b?lib/" };

  is_deeply([ sort keys %seenmod ], [ sort @mod ],
	    "our modules seen vs. required")
    or note explain { seen => \%seenmod };
  
  return 0;
}

exit main();
