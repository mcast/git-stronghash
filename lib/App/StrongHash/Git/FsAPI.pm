package App::StrongHash::Git::FsAPI;
use strict;
use warnings;

use Carp;


=head1 NAME

App::StrongHash::Git::FsAPI - put/get interface to Git repo

=head1 DESCRIPTION

This API matches L<App::StrongHash::FsPOSIX> (a standard filesystem)
but points at a branch in a Git repository, without having that branch
checked out.


=head1 CLASS METHODS

=head2 new($repodir, $branchname)

Future operations will be relative to the branch in that repository.

=cut

sub new {
  my ($class, $repo, $branch) = @_;
  my $self = { repo => $repo, branch => $branch };
  bless $self, $class;
  return $self;
}


=head1 OBJECT METHODS

=head2 repo

Get the directory containing the repository.

=head2 branch

Get the branch name.

=head2 root

Get the root directory.  This is composed of the repository and branch
names, and is provided for generating error messages rather than
operating on data.

=cut

sub repo {
  my ($self) = @_;
  return $self->{repo};
}

sub branch {
  my ($self) = @_;
  return $self->{branch};
}

sub root {
  my ($self) = @_;
  my ($r, $b) = @{$self}{qw{ repo branch }};
  return ":$b/$r";
}


=head2 scan($path)

Return a list of names relative to root of the L</repo>sitory's tree,
which are found on the L</branch> at the named path below that root.
C<$path> defaults to C<>.

Error if the path is not a directory which can be scanned.

=cut

sub scan {
  my ($self, $path) = @_;
  die "unimplemented";
}


=head2 getfh($path)

Return a filehandle on the contents of the file object at C<$path>.

=cut

sub getfh {
  my ($self, $path) = @_;
  die "unimplemented";
  return $fh;
}


1;
