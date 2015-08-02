package App::Git::StrongHash::ObjHasher;
use strict;
use warnings;

our @HASHES;
BEGIN { @HASHES = qw( sha1 sha256 sha384 sha512 ) }
use Digest::SHA @HASHES;

use List::Util qw( sum );
use Carp;
# use YAML 'Dump'; # for debug

use App::Git::StrongHash;


=head1 NAME

App::Git::StrongHash::ObjHasher - multi-algoritm data hashing


=head1 CLASS METHODS

=head2 new(%info)

Return a new object configured to use the given hasher names, object
counts etc..

Fields of C<%info> supported and required are

=over 4

=item htype

Listref of hasher types to calculate.  Valid types are given by
L</htypes>.

=item nci

Total number of commits to be hashed.  This is written to the header,
and the objectid-sorted commit hashes are written next in the file, to
support fast lookup of whether a commit is in a file.

=item nblob

Total count of file-blob data.  This assists calculation of progress
during hashing.

=item nobj

Total object count for the hashes file (including C<nci>).  This
permits calculation of the total file size.

=item blobbytes

Total byte count of file-blob data.  This assists calculation of
progress during hashing.

=back

=cut

sub new {
  my ($class, %info) = @_;
  my $self = { code => App::Git::StrongHash->VERSION };
  bless $self, $class;
  my @left = $self->_init(%info);
  croak "Rejected unrecognised info (@left)" if @left;
  return $self;
}

sub _init {
  my ($self, %info) = @_;

  # Take the config
  my @htype = @{ delete $info{htype} || [] };
  $self->{htype} = \@htype;

  foreach my $key (qw( nci nblob nobj blobbytes )) {
    my $tmp = $self->{$key} = delete $info{$key};
    croak "Required field '$key' missing" unless defined $tmp;
    croak "Invalid $key=$tmp" unless $tmp =~ /^\d+$/;
  }

  # Sanity check
  my %okhtype;
  @okhtype{ $self->htypes } = ();
  croak "nothing to do" unless @htype;
  my @bad = grep { !exists $okhtype{$_} } @htype;
  croak "rejected bad htypes (@bad)" if @bad;

  croak "nci + nblob > nobj" if $self->{nci} + $self->{nblob} > $self->{nobj};
  croak "File format requires nobj < 65536, please split" if $self->{nobj} >= 0x10000;

  # Add non-configuration state
  my @hasher = map { Digest::SHA->new($_) } @htype;
  # update ->clone if adding state
  $self->{hasher} = \@hasher;

  return %info;
}


=head2 htypes()

Return a list of valid names for L</new>.  The choice of which are
strong or useful is delegated to the caller.

=cut

sub htypes {
  return @HASHES;
}


=head1 OBJECT METHODS

=head2 clone()

Return a new object with the same configuration from L</new>, but no
other file or progress state.

=cut

sub clone {
  my ($self) = @_;
  my $new = { %$self };
  delete $new->{qw{ hasher objid }};
  bless $new, ref($self);
  return $new;
}


=head2 header_bin()

Return a binary blob giving the filemagic, program version, configured
digests and other info.

=head2 header_txt()

Return a string (in scalar context, for debugging) or list of
key-value pairs (in list context) constituting the header.

=cut

sub header_bin {
  my ($self) = @_;
  my %kv = $self->header_txt;
  return pack('Z12SA6SSS', @kv{qw{ magic filev progv rowlen nci nobj }});
}

sub header_txt {
  my ($self) = @_;
  my %out =
    (magic => 'GitStrngHash',
     filev => 1,
     progv => $self->{code},
     rowlen => $self->rowlen,
     nci => $self->{nci},
     nobj => $self->{nobj});
  if (!wantarray) {
    require YAML;
    YAML->import('Dump');
    return Dump({ header => \%out });
  } else {
    return %out;
  }
}


=head2 rowlen()

Return number of bytes per binary output hash - the length of
L</output_bin>.

=cut

sub rowlen {
  my ($self) = @_;
  my $git_id_len = 160; # SHA1
  return sum( $git_id_len, map { $_->hashsize } $self->_hashers ) / 8;
}


=head2 newfile($type, $size, $objid)

Reset the hashers for a new file, of given type, size and (full-length
hex) Git objectid.  The contents are given to L</add>.

=cut

sub newfile {
  my ($self, $type, $size, $objid) = @_;

  foreach my $h ($self->_hashers) {
    $h->reset;
  }

  # update ->clone if adding state
  $self->{objid} = $objid;

  return;
}


=head2 objid_hex()

=head2 objid_bin()

Return Git objectid of current file, as given to L</newfile>, either
as hex or binary.

=cut

sub objid_hex {
  my ($self) = @_;
  my $objid = $self->{objid};
  croak "No current file" unless defined $objid;
  return $objid;
}

sub objid_bin {
  my ($self) = @_;
  return pack('H*', $self->objid_hex);
}

sub _hashers {
  my ($self) = @_;
  return @{ $self->{hasher} };
}


=head2 add($data)

Add the chunk of data to each hasher.

=cut

sub add {
  my ($self, $data) = @_;
  foreach my $h ($self->_hashers) {
    $h->add($data);
  }
  return;
}


=head2 output_bin()

Finalise (consume) and return as a binary blob all the digests.

=cut

sub output_bin {
  my ($self) = @_;
  my @hbin = map { $_->digest } $self->_hashers;
  my $out = join '', $self->objid_bin, @hbin;
  undef $self->{objid};
  return $out;
}


=head2 output_hex()

Finalise and return the states of cloned copies of each hasher, as
labelled hexdigests.  In list context, as (key, value) pairs.  In
scalar context as a string.

Doesn't work after L</output_bin> has been called, because that
consumes the state.  This is intended for debugging rather than
efficient processing.

=cut

sub output_hex {
  my ($self) = @_;
  my @h16 = map { $_->clone->hexdigest } $self->_hashers;
  my @hkey = (objid => $self->_hashnames);
  my %out = (objid => $self->objid_hex);
  @out{@hkey} = @h16;
  return %out if wantarray;
  my $txt = (join ' ', map { "$_:$out{$_}" } @hkey)."\n";
  return $txt;
}

{
  my %alg2name =
    qw(	1      SHA-1	
	224    SHA-224	
	256    SHA-256	
	384    SHA-384	
	512    SHA-512	
	512224 SHA-512/224
	512256 SHA-512/256 ); # from L<Digest::SHA/algorithm>

  # well they don't match htypes, so maybe should avoid?  or translate?
  sub _hashnames {
    my ($self) = @_;
    my @halg = map { $_->algorithm } $self->_hashers;
    return map { $alg2name{$_} or die "Unknown Digest::SHA($_)" } @halg;
  }
}
  

1;
