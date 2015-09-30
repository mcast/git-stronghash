package App::StrongHash;
use strict;
use warnings;

use Cwd;
use Getopt::Long;
use App::StrongHash::DfIndex;
use App::StrongHash::DigestReader;
use YAML 'Dump';


our $VERSION = '0.01';

=head1 NAME

App::StrongHash - Bolt-on security for Git repo contents

=head1 DESCRIPTION

=head1 CLASS METHODS

These are the bodies of the scripts which are available as Git
subcommands.


=head2 dump()

=cut

sub dump {
  my ($fn) = @ARGV;
  die "Syntax: $0 <digestfile> | less -S\n" unless 1==@ARGV;
  my $fh;
  if ($fn eq '-') {
    $fh = \*STDIN;
  } else {
    open $fh, '<', $fn or die "Read $fn: $!\n";
  }
  binmode $fh or die "binmode $fn: $!";
  my $dfr = App::StrongHash::DigestReader->new($fn => $fh);
  my %hdr = $dfr->header;
  print Dump({ filename => $fn, header => \%hdr });
  print "...\n";
  my @htype = @{ $hdr{htype} };
  my @hlen = map { App::StrongHash::ObjHasher->packfmt4type($_) } @htype;
  foreach (@hlen) { s/^H//; $_ = "%-${_}s" }
  printf((join ' ', @hlen)."\n", @htype);
  printf((join ' ', @hlen)."\n", ("-" x 10) x @htype);
  local $, = ' ';
  local $\ = "\n";
  while (my ($h) = $dfr->nxt) {
    print @$h;
  }
}


=head2 lookup()

=cut

sub lookup {
  my ($help, $src_is_fns, @htype, @check, @fn);
  GetOptions
    ('help|h' => \$help,
     'files|F' => \$src_is_fns,
     'htype|H=s' => \@htype,
     'check|c=s' => \@check)
    or $help=1;

  my $synt =
    "Syntax: $0 [ --check <objid> ]* [ --htype <hashname> ]+ --files <filename>+\n
Specify objectids to check via --check flag, xor pipe them to stdin.\n
Outputs are on stdout, matching requested htype and objid in order.\n";
  die $synt if $help;
  die "Please request hashtype(s)\n\n$synt" unless @htype;

  if ($src_is_fns) {
    @fn = @ARGV;
  } else {
    die "Please specify lookup digestfiles with --files\n\n$synt";
  }

  $| = 1;
  my $dfi = App::StrongHash::DfIndex->new_files(@fn);
  $dfi->want_htype(@htype);
  local $, = " ";
  local $\ = "\n";
  foreach my $objid (@check) {
    print map {@$_} $dfi->lookup($objid);
  }
  if (!@check) {
    warn "[w] Reading stdin from terminal\n" if -t STDIN;
    while (<STDIN>) {
      chomp;
      print map {@$_} $dfi->lookup($_);
    }
  }
  return 0;
}


1;
