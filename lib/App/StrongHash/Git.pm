package App::StrongHash::Git;
use strict;
use warnings;

use Cwd;
use Getopt::Long;
use File::Temp 'tempfile';
use App::StrongHash::Git::Objects;
use App::StrongHash::DfLister;


=head1 NAME

App::StrongHash::Git - subcommands for git

=head1 DESCRIPTION

=head1 CLASS METHODS

These are the bodies of the scripts which are available as Git
subcommands.


=head2 git_all()

=cut

sub git_all {
  my @ok_htype = App::StrongHash::ObjHasher->htypes;
  my $synt = "Syntax: $0 [ -t <hashtype> ]* [ -o <output> ] [ --subtract <digestfilename>+ ]

Create a new digestfile at the named output filename (defaults to STDOUT).
Digests of each requested type are added (current default is sha256).\n
Valid digest types are: @ok_htype\n\n";

  my (@htype, $out, $subtract);
  GetOptions
    ('htype|t=s', \@htype,
     'subtract|S', \$subtract,
     'out|o=s', \$out)
    or die $synt;

  @htype = qw( sha256 ) unless @htype;
  unshift @htype, 'gitsha1';

  my @digestfile;
  if ($subtract) {
    @digestfile = @ARGV;
    die "--subtract requires filenames" unless @digestfile;
  } else {
    die $synt if @ARGV;
  }

  my ($outfh, $out_tmp);
  if (defined $out && $out ne '-') {
    ($outfh, $out_tmp) = # should be renamed away before unlink
      tempfile("$out.XXXXXX", UNLINK => 1);

  } else {
    die "Will not send binary to terminal" if -t STDOUT;
    $outfh = \*STDOUT;
  }

  my $cwd = cwd();
  my $repo = App::StrongHash::Git::Objects->new($cwd);
  $repo->add_tags->add_commits->add_trees;

  foreach my $df (@digestfile) {
    open my $fh, '<', $df
      or die "Read digestfile $df: $!";
    my $dfl = App::StrongHash::DfLister->new($df, $fh);
    $repo->subtract_seen($dfl);
  }

  my $hasher = $repo->mkhasher(htype => \@htype);
  $repo->mkdigesfile($outfh, $hasher);

  close $outfh; # could be STDOUT or tempfile
  if (defined $out_tmp) {
    unless (rename $out_tmp, $out) {
      unlink $out_tmp or warn "Cleanup (rm $out_tmp) failed: $!";
      die "Rename to $out failed: $!";
    }
  }

  return 0;
}


1;
