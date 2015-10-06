package App::StrongHash::Git::BlobField;
use strict;
use warnings;

use Carp;


=head1 NAME

App::StrongHash::Git::BlobField - "git cat-file" consumer for commits

=head1 DESCRIPTION

This implements the interface of L<App::StrongHash::ObjHasher> used by
L<App::StrongHash::Git::CatFilerator>.

It was written for extracting commit date, but would be the place to
start extending for other fields in blobs.


=head1 CLASS METHODS

=head2 new($regexp)

Return a new object.  C<$regexp> will be applied to each object given
to L</newfile>, when L</match> is called.

=cut

sub new {
  my ($class, $regexp) = @_;
  my $self = { gitsha1 => undef,
	       data => '',
	       regexp => $regexp };
  bless $self, $class;
  return $self;
}


=head1 OBJECT METHODS

=head2 newfile($type, $size, $gitsha1)

Reset for a new object of given type, size and (full-length hex)
gitsha1.  The contents are given to L</add>.

=cut

sub newfile {
  my ($self, $type, $size, $gitsha1) = @_;
  $self->{gitsha1} = $gitsha1;
  $self->{data} = '';
  return;
}


=head2 add($data)

Add the chunk of data to each hasher.

=cut

sub add {
  my ($self, $data) = @_;
  $self->{data} .= $data;
  return;
}


=head2 match()

Apply the regexp once and return an ARRAYref containing C<[ $gitsha1,
@capture ]>.

=cut

sub match {
  my ($self) = @_;
  my @match = $self->{data} =~ $self->{regexp};
  return [ $self->{gitsha1}, @match ];
}


1;
