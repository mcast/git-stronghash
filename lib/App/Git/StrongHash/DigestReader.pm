package App::Git::StrongHash::DigestReader;
use strict;
use warnings;

use App::Git::StrongHash::ObjHasher;


=head1 NAME

App::Git::StrongHash::DigestReader - read digestfile


=head1 CLASS METHODS

=head2 new($fh, $name)

Return a new object.  Nothing is read from $fh yet.  It must be in
C<binmode>.

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
  App::Git::StrongHash::ObjHasher->wantbinmode($fh);
  my $self = { fh => $fh, name => $name };
  bless $self, $class;
  $self->{nxt} = $self->_nxt_init;
  return $self;
}


=head1 OBJECT METHODS

They can be called in any order at any time, caching keeps the
filehandle in the right place.


=head2 header()

Reads, caches and returns the header.  Returns the list of (key,
value) pairs from L<App::Git::StrongHash::ObjHasher/header_bin2txt>.

=cut

sub header {
  my ($self) = @_;
  return %{ $self->{header} } if $self->{header};

  my $fh = $self->_fh;
  my %hdr = App::Git::StrongHash::ObjHasher->header_bin2txt($fh);
  $self->{header} = \%hdr;

  return %hdr;
}

sub _fh {
  my ($self) = @_;
  return $self->{fh};
}


=head2 nxt()

In list context, take C<$list[0]>.

Returns the fetched element, or nothing at the end.

Currently the element is an ARRAYref like C<[$objectid, @hash]> where
the hash types are as given in the header and the format is full
length hexadecimal.  Configuration for this can come later.

=cut

sub nxt {
  my ($self) = @_;
  return $self->{nxt}->();
}

sub _nxt_init {
  my ($self) = @_;
  my $nxt = sub {
    croak "wantarray!" unless wantarray;
    $self->header unless $self->{header};
    my $fh = $self->_fh;
    my $rowlen = $self->{header}{rowlen};
    return $self->_nxt_iter($fh, $rowlen)->();
  };
  return $self->{nxt} = $nxt;
}

sub _nxt_iter {
  my ($self, $fh, $rowlen) = @_;
  my $nxt = sub {
    croak "wantarray!" unless wantarray;
    local $/ = \$rowlen;
    my $binrow = <$fh>;
  };
  return $self->{nxt} = $nxt;
}


=head2 dcount()

As for L<App::Git::StrongHash::Iterator/count> but faster.

=cut

sub dcount {
  my ($self) = @_;
  my $n = @{ $self->{lst} };
  @{ $self->{lst} } = ();
  return $n;
}


1;
