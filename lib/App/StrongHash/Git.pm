package App::StrongHash::Git;
use strict;
use warnings;

use Cwd;
use Getopt::Long;
use App::StrongHash::Git::Objects;


=head1 NAME

App::StrongHash::Git - subcommands for git

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


1;
