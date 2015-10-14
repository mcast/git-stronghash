package App::StrongHash::FsPOSIX;
use strict;
use warnings;


=head1 NAME

App::StrongHash::FsPOSIX - put/get interface to POSIX filesystem

=head1 DESCRIPTION

This API is provided to standard filesystems so that the same
interface can be offered to operate on committed objects on a version
control repository or other file store.


=head1 CLASS METHODS

=head2 new($rootdir)

Future operations will be relative to the root directory given.

=cut

sub new {
  my ($class, $root) = @_;
  my $self = { root => $root };
  bless $self, $class;
  return $self;
}


=head1 OBJECT METHODS

=head2 root

Get the root directory.

=cut

sub root {
  my ($self) = @_;
  return $self->{root};
}


=head2 scan($path)

Return a list of names relative to L</root> which are found at the
named path below the root.  C<$path> defaults to C<>.

Error if the path is not a directory which can be scanned.

=cut

sub scan {
  my ($self, $path) = @_;
  $path = '' unless defined $path;
  my $root = $self->root;
  my $fullpath = "$root/$path";
  opendir my $dh, $fullpath or die "scan($root, $path) failed: $!";
  my @out =
    map { -d $_ ? "$_/" : $_ }
    map {"$fullpath$_"}
    sort(grep { not /^\.\.?$/ }
	 readdir $dh);
  return @out;
}


1;
