package App::Git::StrongHash;
use strict;
use warnings;

use Cwd;
use Getopt::Long;
use App::Git::StrongHash::Objects;

our $VERSION = '0.01';

=head1 NAME

App::Git::StrongHash -  Bolt-on security for Git repo contents

=head1 DESCRIPTION

=head1 CLASS METHODS

These are the bodies of the scripts which are available as Git
subcommands.

=head2 all()

=cut


sub all {
  my @htype;
  GetOptions('htype|t=s', \@htype);
  die "Syntax: $0 [ -t <hashtype> ]* > myrepo.stronghash\n" if @ARGV || -t STDOUT;
  @htype = qw( sha256 ) unless @htype;

  my $cwd = cwd();
  my $repo = App::Git::StrongHash::Objects->new($cwd);
  $repo->add_tags->add_commits->add_trees;
  my $hasher = $repo->mkhasher(htype => \@htype);
  $repo->mkdigesfile(\*STDOUT, $hasher);

  return 0;
}


1;
