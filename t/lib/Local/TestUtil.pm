package Local::TestUtil;
use strict;
use warnings FATAL => 'all';

use App::StrongHash::Piperator;

use Try::Tiny;
use File::Slurp qw( write_file );
use File::Temp 'tempfile';
use base 'Exporter';

our @EXPORT_OK =
  qw( ione plusNL tryerr mkiter detaint t_nxt_wantarray
      test_digestfile_name testdigestfile testrepo_or_skip
      hex2bin bin2hex fh_on
      cover_script );


sub tryerr(&) {
  my ($code) = @_;
  return try { $code->() } catch {"ERR:$_"};
}

sub ione {
  my ($iter) = @_;
  my @i = $iter->nxt;
  fail("expected one, got none") unless @i;
  return $i[0]; # (conflates undef and eof)
}

sub plusNL { [ map {"$_\n"} @_ ] }

sub mkiter {
  my (@ele) = @_;
  # a simple list iterator would be fine as input, but there isn't one yet
  return App::StrongHash::Piperator->new($^X, -e => 'foreach my $e (@ARGV) { print "$e\n" }', @ele);
}

sub detaint {
  my ($in) = @_;
  $in =~ m{^(.*)\z}s or die "untaint fail: $in";
  return $1;
}

sub t_nxt_wantarray {
  my ($iter) = @_;
  my $L = __LINE__; my $sc_nxt = tryerr { scalar $iter->nxt };
  my $file = __FILE__;
  main::like($sc_nxt, qr{^ERR:wantarray! at \Q$file\E line $L\.$}, 'wantarray || croak');
}

sub test_digestfile_name {
  my ($base) = @_;
  my $name = "t/digestfile/v2/$base.stronghash";
  $name = "t/digestfile/v1/$base.stronghash" if !-f $name;
  die "test_digestfile_name($base): $name not found" unless -f $name;
  return $name;
}

sub testdigestfile {
  my ($base) = @_;
  my $fn = test_digestfile_name($base);
  open my $fh, '<', $fn or die "Read $fn: $!";
  binmode $fh or die $!;
  return $fh;
}

sub testrepo_or_skip {
  my ($suffix) = @_;
  my $testrepo = $0;
  my $name = 'test-data';
  $name .= $suffix if defined $suffix;
  $testrepo =~ s{t/\S+\.t$}{t/testrepo/$name}
    or die "Can't make $name/ on $testrepo";
  unless (-d $testrepo && -f "$testrepo/.git/config") {
    main::note " => # (cd t/testrepo && git clone $testrepo.bundle) # will make it";
    main::plan skip_all => "$name/ not expanded from bundle?";
  }
  return $testrepo;
}

# tacky conversion of "hexdump -C" to binary
sub hex2bin {
  my ($txt) = @_;
  return '(undef input)' unless defined $txt;
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

sub fh_on {
  my ($name, $blob, $layer) = @_;
  $layer = '' unless defined $layer;
  # (open $fh, '<', \$data) are incompatible with sysread (but I
  # stopped using).
  #
  # IO::String was incompatible with (local $/ = \16).
  # (open \$data) was giving me utf8 decoding issues.
  #
  # There may be a better way round all this, but the test should
  # pass anyway.
  my ($fh, $filename) = # unlink here
    tempfile("07objhasher.$name.XXXXXX", TMPDIR => 1, UNLINK => 1);
  binmode $fh or die $!;
  print {$fh} $blob or die "print{$filename}: $!";
  close $fh or die "close{$filename}: $!";
  open $fh, "<$layer", $filename or die "re-open(<$layer $filename): $!";
  unlink $filename;
  return $fh;
}

sub cover_script {
  if (defined (my $hps = delete $ENV{HARNESS_PERL_SWITCHES})) {
    # e.g. " -MDevel::Cover=-db,/mumble/git-stronghash/cover_db"
    my ($cover) = $hps =~ m{\s(-MDevel::Cover=\S+)(\s|$)}
      or die "Got HARNESS_PERL_SWITCHES='$hps' with no coverage options";
    die "PERL5OPT='$ENV{PERL5OPT}' already..?" if defined $ENV{PERL5OPT};
    $ENV{PERL5OPT} = $cover;
  }
  return;
}


1;
