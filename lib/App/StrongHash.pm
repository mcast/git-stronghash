package App::StrongHash;
use strict;
use warnings;

use Cwd;
use Getopt::Long;
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
