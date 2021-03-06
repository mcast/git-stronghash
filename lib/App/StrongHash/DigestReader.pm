package App::StrongHash::DigestReader;
use strict;
use warnings;

use Carp;
use App::StrongHash::ObjHasher;

use parent 'App::StrongHash::Iterator';


=head1 NAME

App::StrongHash::DigestReader - read digestfile


=head1 DESCRIPTION

This is a read-back interface for L<App::StrongHash::ObjHasher>.  It
reads and stores the header of the digestfile, then provides an
L<App::StrongHash::Iterator> interface to the rows.


=head1 CLASS METHODS

=head2 new($name, $fh)

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
  my ($class, $name, $fh) = @_;
  App::StrongHash::ObjHasher->wantbinmode($fh);
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
value) pairs from L<App::StrongHash::ObjHasher/header_bin2txt>.

=cut

sub header {
  my ($self) = @_;
  return %{ $self->{header} } if $self->{header};

  my $fh = $self->_fh;
  my %hdr = App::StrongHash::ObjHasher->header_bin2txt($fh);
  $self->{header} = \%hdr;

  return %hdr;
}

sub _fh {
  my ($self) = @_;
  return $self->{fh};
}


=head2 htype()

Return the htype (including the first index-by type) as a list.

=cut

sub htype {
  my ($self) = @_;
  $self->{htype} ||= do {
    my %h = $self->header;
    $h{htype};
  };
  return @{ $self->{htype} };
}


=head2 nxt()

In list context, take C<$list[0]>.

Returns the fetched element, or nothing at the end.

Currently the element is an ARRAYref like C<[$gitsha1, @hash]> where
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
    my %hdr = $self->header;
    my $fh = $self->_fh;
    my $rowlen = $hdr{rowlen};
    my $fmt = join ' ',
      map { App::StrongHash::ObjHasher->packfmt4type($_) }
      @{ $hdr{htype} };
    return $self->_nxt_iter($fh, $rowlen, $fmt)->();
  };
  return $self->{nxt} = $nxt;
}

sub _nxt_iter {
  my ($self, $fh, $rowlen, $fmt) = @_;
  my $nxt = sub {
    croak "wantarray!" unless wantarray;
    my $binrow = do { local $/ = \$rowlen; <$fh> };
    if (!defined $binrow) {
      $self->{nxt} = $self->_nxt_eof;
      return ();
    }
    my @out = unpack($fmt, $binrow);
    return \@out;
  };
  return $self->{nxt} = $nxt;
}

sub _nxt_eof {
  my ($self) = @_;
  undef $self->{fh}; # just drop it, caller might close
  return sub {
    croak "wantarray!" unless wantarray;
    return ();
  };
}


=head2 nxtout_to_hash($listref)

Utility method to turn a list returned by L</nxt> into a hashref of
C<($htype => $hashvalue)> using L</htype>.

=cut

sub nxtout_to_hash {
  my ($self, $l) = @_;
  my @k = $self->htype;
  my %out;
  @out{@k} = @$l;
  return \%out;
}


1;
