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

=head2 new($repo, $branchname)

Future operations will be relative to the branch in that repository.
$repo may be an L<App::StrongHash::Git::Objects> or a directory name.

=cut

sub new {
  my ($class, $repo, $branch) = @_;
  $repo = App::StrongHash::Git::Objects->new($repo) unless ref($repo);
  my $self = { repo => $repo, branch => $branch };
  bless $self, $class;
  return $self;
}


=head1 OBJECT METHODS

=head2 repo

Get the L<App::StrongHash::Git::Objects> representing the repository.

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
  my $r = $self->repo->dir;
  my $b = $self->branch;
  return ":$b/$r";
}


=head2 scan($path)

Return a list of names relative to root of the L</repo>sitory's tree,
which are found on the L</branch> at the named path below that root.
C<$path> defaults to C<>.

The branch is as seen when L<App::StrongHash::Git::Objects/add_refs>
was called on the L</repo>.  Error if the branch is invalid.

Error if the path is not a directory which can be scanned.

=cut

sub scan {
  my ($self, $path) = @_;
#  my $ciid = $
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
