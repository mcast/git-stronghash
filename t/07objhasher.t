#!perl
use strict;
use warnings FATAL => 'all';

use List::Util qw( sum );
use File::Slurp qw( slurp write_file );
use YAML qw( LoadFile Dump );
use Test::More;

use App::Git::StrongHash;
use App::Git::StrongHash::ObjHasher;
use App::Git::StrongHash::Objects;

use lib 't/lib';
use Local::TestUtil qw( testrepo_or_skip );
#use Local::TestUtil qw( mkiter tryerr plusNL ione t_nxt_wantarray );

# tacky conversion of "hexdump -C" to binary
sub hex2bin {
  my ($txt) = @_;
  my $out = '';
  foreach my $ln (split /\n/, $txt) {
    my $orig = $ln;
    die "need addr on $orig" unless $ln =~ s{^[0-9a-f]{8}(  +\b|\n?$)}{};
    next if $ln eq '';
    $ln =~ s{  \|.{1,16}\|$}{}; # optional ASCII translation
    my @byte = $ln =~ m{\b([0-9a-f]{2})\b}g;
    die "no hexbytes in $orig ($ln)" unless @byte;
    $out .= join '', map { chr(hex($_)) } @byte;
  }
  return $out;
}

sub bin2hex {
  my ($bin) = @_;
  return "(devel code exists to generate hexdump)";
  write_file("$0.tmp~", $bin);
  my $hd = `hexdump -C $0.tmp~`;
  return $hd;
}

sub main {
  my $testrepo = testrepo_or_skip();
  my $OH = 'App::Git::StrongHash::ObjHasher';
  my ($DATA) = LoadFile("$0.yaml");

  plan tests => 6;

  is(hex2bin($DATA->{'test-data/ten'}), slurp("$testrepo/ten"), "hex2bin util");

  my @HT = $OH->htypes;
  my $H = $OH->new(htype => \@HT, nci => 1, nobj => 1, nblob => 0, blobbytes => 0);
  $H->newfile(commit => 200, '0123456789abcdef0123456789abcdef01234567');
  cmp_ok(length($H->output_bin), '==', $H->rowlen, "length(output_bin) == rowlen");
  note $H->rowlen, " byte";

  my $txt = slurp("$testrepo/0hundred");
  $H->newfile(commit => length($txt), '0123456789abcdef0123456789abcdef01234567');
  $H->add($txt);
  my %row = $H->output_hex;
  my $row = $H->output_hex;
  my $bin = $H->output_bin;
  my $want = $DATA->{'01hundred_sums'};
  is_deeply(\%row, $want->{kvp}, "01hundred_sums kvp")
    or diag Dump({ row => \%row });
  is($row, $want->{txt}, "01hundred_sums txt");
  is($bin, hex2bin($want->{bin}), "01hundred_sums bin")
    or diag bin2hex($bin);

#  my $repo = App::Git::StrongHash::Objects->new($testrepo);
  
  is(App::Git::StrongHash->VERSION, '0.01', 'XXX: compare to header');

  return 0;
}


exit main();
