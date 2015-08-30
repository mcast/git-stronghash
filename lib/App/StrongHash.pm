package App::StrongHash;
use strict;
use warnings;

use Cwd;
use Getopt::Long;
use App::StrongHash::Git::Objects;
use App::StrongHash::DigestReader;
use YAML 'Dump';


our $VERSION = '0.01';

=head1 NAME

App::StrongHash -  Bolt-on security for Git repo contents

=head1 DESCRIPTION

=head1 CLASS METHODS

These are the bodies of the scripts which are available as Git
subcommands.

=head2 git_all()

=cut


sub git_all {
  my @htype;
  GetOptions('htype|t=s', \@htype);
  die "Syntax: $0 [ -t <hashtype> ]* > myrepo.stronghash\n" if @ARGV || -t STDOUT;
  @htype = qw( sha256 ) unless @htype;
  unshift @htype, 'gitsha1';

  my $cwd = cwd();
  my $repo = App::StrongHash::Git::Objects->new($cwd);
  $repo->add_tags->add_commits->add_trees;
  my $hasher = $repo->mkhasher(htype => \@htype);
  $repo->mkdigesfile(\*STDOUT, $hasher);

  return 0;
}

=head2 dump()

=cut

sub dump {
  my ($fn) = @ARGV;
  die "Syntax: $0 <digestfile> | less -S\n" unless 1==@ARGV;
  open my $fh, '<', $fn or die "Read $fn: $!\n";
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


1;