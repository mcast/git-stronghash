#!perl
use strict;
use warnings FATAL => 'all';

use File::Slurp qw( slurp read_dir );
use Test::More;
use Cwd 'abs_path';

use lib 't/lib';
use Local::TestUtil qw( cover_script );


sub main {
  run_absolute();
  plan tests => 7;

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
    next unless $modfn =~ m{^App/StrongHash};
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

  my @t = grep { /\.t$/ && -f $_ }
    map {"$base/t/$_"} read_dir("$base/t");
  my @use = map { /^\s*use\s+(App::StrongHash\b.*?)(?: |;)/ ? ($1) : () }
    map { slurp($_) } @t;
  my %uq;
  @uq{@use} = ();
  @use = sort keys %uq;
  my @mod_s = sort @mod;
  is_deeply(\@use, \@mod_s, "test use'd vs. mods named")
    or diag explain { listed_for_00 => \@mod_s, tested => \@use, in_testfiles => \@t };

  my @gitty = grep { /:Git:/ } map { nl($_ => slurp($_)) } # source line matching,
    grep { ! m{/Git(/|\.pm$)} } values %seenmod; # among files not titled .../Git/...
  chomp @gitty;
  is(scalar @gitty, 0, "App::StrongHash:: modules mentioning App::StrongHash::Git::")
    or note explain { gitty => \@gitty };

  my @testfiles = (<t/*.t>, <t/lib/Local/*.pm>);
  my @allcode = map { nl($_ => slurp($_)) } (values %seenmod, @testfiles);
  chomp @allcode;
  my @templitter =
    grep { /\btempfile\b/ && ! /use File::Temp/ && ! /UNLINK/ }
    map { s{(\s*#\s*)[^"'#{}]+$}{$1...}r }
    @allcode;
  is_deeply(\@templitter, [], # I've been forgetting them
	    'tempfile(...) without explicit UNLINK')
    or note explain { templitter => \@templitter };

  subtest podHEAD1s => sub { t_podHEAD1(%seenmod); };

  return 0;
}


sub run_absolute {
  my $abs = abs_path($0);
  if ($abs eq $0) {
    # $0 is absolute, which (via conditionals in Devel::Cover, I think)
    # allows $PWD/blib/lib/* coverage stats to merge into blib/lib/*
    shift @ARGV if $ARGV[0] eq '--recursing';
  } else {
#    cover_script();
# Telling the re-exec to run Devel::Cover shows the rest of main(),
# but then loses A:G:SH->all
    die "Fallen down the recursion well, while trying to run under absolute path?!"
      if "@ARGV" =~ /recursing/;
    exec($^X, $abs, "--recursing", @ARGV) unless $abs eq $0;
  }
}

sub nl {
  my ($fn, @line) = @_;
  for (my $i=0; $i<@line; $i++) {
    my $n = $i + 1;
    $line[$i] = "$fn:$n:$line[$i]";
  }
  return @line;
}


sub t_podHEAD1 {
  my (%mod2fn) = @_;
  my @essential = qw( NAME DESCRIPTION );
  note "\nModule POD =HEAD1s\n\n";
  foreach my $mod (sort keys %mod2fn) {
    my $fn = $mod2fn{$mod};
    my @txt = slurp($fn);
    my @head1 = map { m{^=head1\s+(.*)$} ? ($1) : () } @txt;
    my %H;
    @H{@head1} = (1) x @head1;
    my @missing = grep { !$H{$_} } @essential;
    is("@missing", "", "missing from $fn");
    note sprintf("%-40s: %s\n", $mod, join ' | ', @head1);
  }
  return;
}

exit main();
