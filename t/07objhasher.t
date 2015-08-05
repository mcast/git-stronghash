#!perl
use strict;
use warnings FATAL => 'all';

use List::Util qw( sum );
use File::Slurp qw( slurp write_file );
use YAML qw( LoadFile Dump Load );
use Test::More;
use File::Temp 'tempfile';

use App::Git::StrongHash;
use App::Git::StrongHash::ObjHasher;

use lib 't/lib';
use Local::TestUtil qw( testrepo_or_skip tryerr );

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
  my ($name, $blob) = @_;
  # (open $fh, '<', \$data) are incompatible with sysread.
  # IO::String was incompatible with (local $/ = \16).
  # (open \$data) was giving me utf8 decoding issues.
  #
  # There may be a better way round all this, but the test should
  # pass anyway.  Beware, we mix print+sysread here!
  my ($fh, $filename) = tempfile("07objhasher.$name.XXXXXX", TMPDIR => 1);
  $fh->autoflush(1);
  print {$fh} $blob or die "print{$filename}: $!";
  sysseek $fh, 0, 0 or die "sysseek($filename): $!";
  return $fh;
}

sub main {
  my $testrepo = testrepo_or_skip();
  my $OH = 'App::Git::StrongHash::ObjHasher';
  my $JUNK_CIID = '0123456789abcdef0123456789abcdef01234567';
  my ($DATA) = LoadFile("$0.yaml");

  plan tests => 13;

  foreach my $path (qw( to_header/text to_header/h2_text from_header/out )) {
    my @p = split m{/}, $path;
    my $h = $DATA->{$p[0]}{$p[1]};
    die "Can't update path $path ($h->{progv})"
      unless $h->{progv} eq 'x.yy_replaced_in_test_code';
    $h->{progv} =
      App::Git::StrongHash->VERSION;
  }

  is(hex2bin($DATA->{'test-data/ten'}), slurp("$testrepo/ten"), "hex2bin util");

  my @HT = $OH->htypes;
  my %OK = (htype => \@HT, nci => 1, nobj => 1, nblob => 0, blobbytes => 0);
  my $H = $OH->new(%OK);
  $H->newfile(commit => 200, $JUNK_CIID);
  cmp_ok(length($H->output_bin), '==', $H->rowlen, "length(output_bin) == rowlen");
  note $H->rowlen, " byte";

  foreach my $method (qw( output_hex output_bin objid_hex objid_bin )) {
    my $L = __LINE__; my $got = tryerr { $H->$method };
    like($got, qr{^ERR:No current file at \Q$0\E line $L\.}, "$method before newfile");
  }

  my $txt = slurp("$testrepo/0hundred");
  $H->newfile(commit => length($txt), $JUNK_CIID);
  $H->add($txt);
  subtest '0hundred' => sub {
    my %row = $H->output_hex;
    my $row = $H->output_hex;
    my $bin = $H->output_bin;
    my $want = $DATA->{'01hundred_sums'};
    is_deeply(\%row, $want->{kvp}, "01hundred_sums kvp")
      or diag Dump({ row => \%row });
    is($row, $want->{txt}, "01hundred_sums txt");
    is($bin, hex2bin($want->{bin}), "01hundred_sums bin")
      or diag bin2hex($bin);

    $H->{objid} = $JUNK_CIID; # to prevent croak 'No current file'
    # nb. hasher state otherwise unchanged
    my $lost_row = $H->output_hex;
    is($lost_row, $want->{lost_txt}, "hasher state is lost, output is digest(0 bytes)");

    $H->newfile(commit => length($txt), $JUNK_CIID);
    $H->add(sprintf("%03d\n", $_)) foreach (1..100);
    is($H->output_hex, $row, "same with chunked add");
  };

  $H->{hasher}->[0] = Local::MockDigest->new;
  like(tryerr { scalar $H->output_hex },
       qr{^ERR:Unknown digest Local::MockDigest\(bogus\) at \S*/ObjHasher\.pm line},
       "exercise bogodigest message");

  subtest bad_init => sub {
    my %tst = %OK;

    my $got = tryerr { $OH->new(%tst, junk => 42) }; my $L = __LINE__;
    like($got, qr{^ERR:Rejected unrecognised info \(junk 42\) at \Q$0 line $L.\E}, "left");

    $got = tryerr { local $tst{htype} = undef; $OH->new(%tst) }; $L = __LINE__;
    like($got, qr{^ERR:nothing to do at \Q$0 line $L.\E}, "no htype");

    $got = tryerr { local $tst{htype} = [ "spork", @HT, "wellies" ]; $OH->new(%tst) }; $L = __LINE__;
    like($got, qr{^ERR:rejected bad htypes \(spork wellies\) at \Q$0 line $L.\E}, "bad htype");

    $got = tryerr { local $tst{nblob} = undef; $OH->new(%tst) }; $L = __LINE__;
    like($got, qr{^ERR:Required field 'nblob' missing at \Q$0 line $L.\E}, "missing");

    $got = tryerr { local $tst{nci} = "splee"; $OH->new(%tst) }; $L = __LINE__;
    like($got, qr{^ERR:Invalid nci=splee at \Q$0 line $L.\E}, "bad num");

    $got = tryerr { local $tst{nblob} = 1; $OH->new(%tst) }; $L = __LINE__;
    like($got, qr{^ERR:nci \+ nblob > nobj at \Q$0 line $L.\E}, "nobj small");

    $got = tryerr { local @tst{qw{ nci nobj }} = (1E5, 1E5); $OH->new(%tst) }; $L = __LINE__;
    like($got, qr{^ERR:File format requires nobj < 65536, please split at \Q$0 line $L.\E}, "nci big");
  };

  subtest clone => sub {
    my $H = $OH->new(%OK);
    my $old = $H->clone;
    $H->newfile(commit => length($txt), $JUNK_CIID);
    $H->add($txt);
    my $out1 = $H->output_bin;
    $H->newfile(commit => length("blah"), $JUNK_CIID);
    $H->add("blah");
    my $new = $H->clone;
    is_deeply($new, $old, "clone drops state")
      or diag Dump({ old => $old, H => $H, new => $new });
    cmp_ok(scalar keys %$new, '<', scalar keys %$H, 'keys were deleted')
      or diag explain { new => [ sort keys %$new ], H => [ sort keys %$H ] };
    $new->newfile(commit => length($txt), $JUNK_CIID);
    $new->add($txt);
    my $out_new = $new->output_bin;
    is($out_new, $out1, "post-clone digests match");
  };

  subtest ciid => sub {
    my $H = $OH->new(%OK);
    my $T = $DATA->{ciid};
    $H->newfile(blob => 123, $T->{hex});
    is($H->objid_hex, $T->{hex}, "objid_hex");
    is($H->objid_bin, hex2bin($T->{bin}), "objid_bin")
      or diag bin2hex($H->objid_bin);
  };

  subtest to_header => sub {
    my $H = $OH->new(%OK);
    my $T = $DATA->{to_header};
    my $hdr = $H->header_bin;
    my %hdr = $H->header_txt;
    my $hdrtxt = $H->header_txt;

    is_deeply(\%hdr, $T->{text}, "text expected")
      or diag explain \%hdr;
    is_deeply({ header => \%hdr }, Load($hdrtxt), "text equiv")
      or diag $hdrtxt;
    is($hdr, hex2bin($T->{bin}), "binary")
      or diag bin2hex($hdr);
    cmp_ok(length($hdr), '==', $hdr{hdrlen}, "header length in header");

    my %ordered;
    @ordered{ @{ $hdr{_order} } } = ();
    my @unordered = grep { !exists $ordered{$_} } sort keys %hdr;
    is("@unordered", "_order _pack", "header fields not in the ordering");

    my %tst2 = (%OK, htype => [ 'sha256' ], nci => 64, nobj => 1024);
    my $H2 = $OH->new(%tst2);
    is_deeply({ $H2->header_txt }, $T->{h2_text}, "H2 text");

    my $L;
    my $oflow = 9357;
    my $H3 = $OH->new(%OK, htype => [ ('sha256') x $oflow ]);
    like(tryerr { $L = __LINE__; $H3->header_bin },
	 qr{^ERR:Overflowed uint16 on header field rowlen=>299444 at \Q$0 line $L.},
	 "H3 row: short overflow");
    $H3 = $OH->new(%OK, htype => [ ('sha256') x ($oflow+1) ]);
    like(tryerr { $L = __LINE__; $H3->header_bin },
	 qr{^ERR:Overflowed uint16 on header field hdrlen=>65537 at \Q$0 line $L.},
	 "H3 hdr: short overflow");
  };

  subtest from_header => sub {
    my $T = $DATA->{from_header};
    my %in = %{ $T->{in} };
    my $hdr = $OH->new(%in)->header_bin;
    my %out = $OH->header_bin2txt($hdr);
    note bin2hex($hdr);
    is_deeply(\%out, $T->{out}, "recovered header (bin)");

    my $fh = fh_on(valid => $hdr."WHATSNEXT\nETC\n");
    %out = $OH->header_bin2txt($fh);
    is_deeply(\%out, $T->{out}, "recovered header (fh)");
    my $buf;
    sysread($fh, $buf, 10) or die "sysread 10: $!";
    is($buf, "WHATSNEXT\n", "fh ready at first row");

    like(tryerr { local $SIG{__WARN__} = sub {}; $OH->header_bin2txt(\*JUNK); my $no_warn = \*JUNK },
	 qr{^ERR:Failed sysread'ing header magic: Bad file descriptor at \Q$0 line},
	 "sysread JUNK GLOB");

    # EOFs
    my $hdr_longwant = pack('a12 n3', @out{qw{ magic filev }}, 1024, 1234);
    is_deeply([ $OH->header_bin2txt("HARDLY_A_BITE") ], [ 16 ], "demand magicful of binstring");
    is_deeply([ $OH->header_bin2txt($hdr_longwant) ], [ 1024 ], "demand the whole binstring");
    like(tryerr { $OH->header_bin2txt(fh_on(nomagic => "HARDLY_A_BITE")) },
	 qr{^ERR:EOF before header magic \Q(got 13) at $0 line }, "EOF on header magic");
    like(tryerr { $OH->header_bin2txt(fh_on(shorthead => $hdr_longwant)) },
	 qr{^ERR:EOF before end of header \Q(got 2) at $0 line }, "EOF on header");

    like(tryerr { $OH->header_bin2txt("THE_WRONG_BITES_ARE_USELESS") },
	 qr{^ERR:Bad file magic.* at \Q$0 line}, "bad magic");
    my $AB = 0x4142;
    my $VSN = App::Git::StrongHash->VERSION;
    like(tryerr { $OH->header_bin2txt("$out{magic}ABCD") },
	 qr{^ERR:Bad file version $AB, only 1 known by code v$VSN at \Q$0 line}, "bad magic");
  };

  return 0;
}


exit main();


package
  Local::MockDigest;
sub new { bless {}, __PACKAGE__ }
sub clone { return $_[0] }
sub algorithm { "bogus" }
sub hexdigest { "deadc0ffeebea7" }

1;
