package App::Git::StrongHash::DigestReader;
use strict;
use warnings;

use App::Git::StrongHash::ObjHasher;


=head1 NAME

App::Git::StrongHash::DigestReader - read digestfile


=head1 CLASS METHODS

=head2 new($fh, $name)

Return a new object.  Nothing is read from $fh yet.

Name is used only for generating messages.

Filehandle will be read B<using C<read>> from current position, which
should be at the beginning of the file and in C<binmode>.  It will be
consumed up to the end of the file (going by the counts in the
header).

We read a stream because the file probably comes out of a pipe.  The
largest file C<qw( sha1 sha256 sha384 sha512 ) * 65536 + header> is
about 11.5 MiB, but there is current no need for random access.

=cut

sub new {
  my ($class, $fh, $name) = @_;
  my $self = { fh => $fh, name => $name };
  bless $self, $class;
  return $self;
}


=head1 OBJECT METHODS

=head2 

=cut


1;
