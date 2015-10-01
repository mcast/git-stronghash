package App::StrongHash::ObjHasher;
use strict;
use warnings;

our @HASHES;
BEGIN { @HASHES = qw( sha1 sha256 sha384 sha512 ) }
use Digest::SHA @HASHES;

use List::Util qw( sum );
use Carp;
# use YAML 'Dump'; # for debug

use App::StrongHash;


=head1 NAME

App::StrongHash::ObjHasher - multi-algoritm data hashing


=head1 DESCRIPTION

This is the core of the Digestfile format.  It describes the header
and body, and makes calls to standard hashing functions when fed data.


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
and the gitsha1-sorted commit hashes are written next in the
digestfile, to support fast lookup of whether a commit is present.

=item nblob

Total count of file-blob data.  This assists calculation of progress
during hashing.

=item nobj

Total object count for the digestfile (including C<nci>).  This
permits calculation of the total file size.

=item blobbytes

Total byte count of file-blob data.  This assists calculation of
progress during hashing.

=back

=cut

sub new {
  my ($class, %info) = @_;
  my $self = { code => App::StrongHash->VERSION };
  bless $self, $class;
  my @left = $self->_init(%info);
  croak "Rejected unrecognised info (@left)" if @left;
  return $self;
}

sub _minimal { # suitable for new
  (htype => [qw[ gitsha1 sha256 ]], nci => 0, nobj => 1);
}

sub _init {
  my ($self, %info) = @_;

  # Take the config
  my @htype = @{ delete $info{htype} || [] };
  if (@htype) {
    $self->_htype_indexby(shift @htype);
  }
  $self->{htype} = \@htype;

  foreach my $key (qw( nci nblob nobj blobbytes )) {
    my $tmp = $self->{$key} = delete $info{$key};
    if (!defined $tmp) {
      croak "Required field '$key' missing" unless $self->_optional($key);
    } else {
      croak "Invalid $key=$tmp" unless $tmp =~ /^\d+$/;
    }
  }

  # Sanity check
  my %okhtype;
  @okhtype{ $self->htypes } = ();
  croak "nothing to do" unless @htype;
  my @bad = grep { !exists $okhtype{$_} } @htype;
  croak "rejected bad htypes (@bad)" if @bad;

  croak "nci + nblob > nobj" if $self->{nci} + ($self->{nblob} || 0) > $self->{nobj};
  croak "Digestfile format requires nobj < 65536, please split" if $self->{nobj} >= 0x10000;

  # just to roundtrip a header
  delete @info{qw{ magic filev hdrlen rowlen progv comment }};

  return %info;
}

{
  my %OPTIONAL =
    (nblob => 1, blobbytes => 1, # because they are just for progress
     # (or have setters for progress-related fields?)
    );
  sub _optional {
    my ($class, $fieldname) = @_;
    return $OPTIONAL{$fieldname};
  }
}


=head2 htypes()

Return a list of valid names for L</new>.  The choice of which are
strong or useful is delegated to the caller.

=cut

sub htypes {
  return @HASHES;
}


=head2 header_bin2txt($fh)

=head2 header_bin2txt($bin)

Read the header in a filehandle or binary string and return the
translated list of (key, value) pairs.  May generate errors.

Filehandles will be read B<using C<read>> from current position
(presumably start of file) and left ready to read the first hash row;
or at an undefined position on error.

If the binary string is not long enough, return just the required
total number of bytes (one element).  64k is definitely plenty.  This
part of the interface looks ugly and might change.

=cut

sub header_bin2txt {
  my ($called, $in) = @_;
  my $class = ref($called) || $called;

  my ($buf, $fh, $add) = ('', 0, 16);
  if (ref($in)) {
    $fh = $in;
    $class->wantbinmode($fh);
    my $nread = read($fh, $buf, $add);
    croak "Failed read'ing header magic: $!" unless defined $nread;
    croak "EOF before header magic (want $add, got $nread)" unless $nread >= $add;
  } else {
    $buf = $in;
  }

  return $add if length($buf) < $add; # more!
  my ($magic, $filev, $hdrlen) = unpack('a12 n2', $buf);

  croak "Bad file magic - is this a 'git stronghash' digests file?"
    unless $magic eq HEADER_MAGIC();
  my @OKVSN = (1, 2);
  croak "Bad file version $filev, only @OKVSN known by code v".App::StrongHash->VERSION
    unless grep { $_ == $filev } @OKVSN;

  if ($hdrlen > length($buf)) {
    if ($fh) {
      $add = $hdrlen - length($buf);
      my $nread = read($fh, $buf, $add, length($buf));
      # uncoverable branch true
      croak "Failed read'ing header: $!" unless defined $nread;
      croak "EOF before end of header (want $add more, got $nread)" unless length($buf) == $hdrlen;
    } else {
      return $hdrlen; # more!
    }
  }

  my %sample = $class->new($class->_minimal)->header_txt;
  my %out;
  @out{ @{$sample{_order}} } = unpack($sample{_pack}, $buf);
  $out{htype} = [ split ',', $out{htype} ];

  # After first release, we're stuck with all extant filev!
  # People will be getting digestfiles hashed and signed.
  if ($filev == 1) {
    # ...assumed 'gitsha1' as first element of htype
    unshift @{ $out{htype} }, 'gitsha1';  # TODO:HTYPE remove when filev=1 gone
  }

#  $out{_rawhdr} = $buf if $keep_hdr;
#  main::diag main::bin2hex($buf);

  return %out;
}


=head2 wantbinmode($fh)

Insist that the filehandle is in C<binmode>.  Returns $fh if it is.

=cut

our $LAX_BINMODE = 0; # for testing
sub wantbinmode {
  my ($called, $fh) = @_;
  return $fh if $LAX_BINMODE;
  my @layers = PerlIO::get_layers($fh);
  my $layers = join '+', @layers;
  if (!@layers) {
    $layers = '(closed?)';
    $layers = 'scalar!' unless ref($fh);
  }
  confess "Filehandle $fh should be in binmode but is $layers"
    unless grep { $layers eq $_ } qw{ unix unix+perlio };
  return $fh;
}


=head2 packfmt4type($htype)

Return the text string suitable for C<pack> or C<unpack> to transform
the given hash type.

Git objectids are known as C<gitsha1>.

Unrecognised names generate an error.

=cut

sub packfmt4type {
  my ($called, $htype) = @_;
  return 'H40' if $htype eq 'gitsha1';
  my $bit = Digest::SHA->new($htype)->hashsize;
  return 'H'.($bit / 4);
}

=head1 OBJECT METHODS

=head2 clone()

Return a new object with the same configuration from L</new>, but no
other file or progress state.

=cut

sub clone {
  my ($self) = @_;
  my $new = { %$self };
  delete @{$new}{qw{ _hasher gitsha1 }};
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
  return pack($kv{_pack}, @kv{ @{ $kv{_order} }});
}

sub HEADER_MAGIC() { 'GitStrngHash' }

sub header_txt {
  my ($self) = @_;
  my @hdr =
    (_pack =>'a12 n5 Z* Z* Z*',
     magic => HEADER_MAGIC(),
     filev => 2,
     hdrlen => undef, # later
     rowlen => $self->rowlen,
     nci => $self->{nci},
     nobj => $self->{nobj},
     progv => $self->{code},
     htype => (join ',', $self->_htype),
     comment => 'n/c', # TODO: add API for optional comment

     # local timestamp - an obvious thing to include, but what value?
     # strong timestamped signatures will follow anyway, it's just
     # clutter
    );
  my %out = @hdr;
  $out{_order} = [ grep { !/^_/ } map { $hdr[ $_ * 2 ] } (0 .. $#hdr/2) ];
  $out{hdrlen} = 12 + 2*5 + length(join 0, @out{qw{ progv htype comment }}, '');

  foreach my $k (qw( filev hdrlen rowlen nci nobj )) {
    my $v = $out{$k};
    # uncoverable condition left
    # uncoverable condition right
    # uncoverable branch true
    croak "Bad header field $k=>$v" unless $v =~ /^\d+$/ && $v >= 0;
    croak "Overflowed uint16 on header field $k=>$v" unless $v < 0x10000;
  }

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


=head2 newfile($type, $size, $gitsha1)

Reset hashers for a new object of given type, size and (full-length
hex) gitsha1.  The contents are given to L</add>.

=cut

sub newfile {
  my ($self, $type, $size, $gitsha1) = @_;

  foreach my $h ($self->_hashers) {
    $h->reset;
  }

  # update ->clone if adding state
  $self->{gitsha1} = $gitsha1;

  return;
}


=head2 gitsha1_hex()

=head2 gitsha1_bin()

Return gitsha1 of current object, as given to L</newfile>, either as
hex or binary.

=cut

sub gitsha1_hex {
  my ($self) = @_;
  my $gitsha1 = $self->{gitsha1};
  croak "No current object" unless defined $gitsha1;
  return $gitsha1;
}

sub gitsha1_bin {
  my ($self) = @_;
  return pack('H*', $self->gitsha1_hex);
}

# the type of all hash columns in the file
sub _htype {
  my ($self) = @_;
  return (gitsha1 => $self->_htype_add);
}

# the first column of hashes, by which we identify objects
sub _htype_indexby {
  my ($self, $set) = @_;
  die "set only, so far" unless defined $set;
  croak 'first htype must be gitsha1 (until we have alternatives)'
    unless $set eq 'gitsha1';
  # it isn't stored, it is just wired in everywhere
  return;
}

# hash type where we read the data to make the hash
sub _htype_add {
  my ($self) = @_;
  return @{ $self->{htype} };
}

sub _hashers {
  my ($self) = @_;
  $self->{_hasher} ||= [ map { Digest::SHA->new($_) } $self->_htype_add ];
  return @{ $self->{_hasher} };
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
  my $out = join '', $self->gitsha1_bin, @hbin;
  undef $self->{gitsha1};
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
  my @hkey = ($self->_hashnames);
  my %out = (gitsha1 => $self->gitsha1_hex);
  @out{@hkey} = @h16;
  return %out if wantarray;
  my $txt = (join ' ', map { "$_:$out{$_}" } (gitsha1 => @hkey))."\n";
  return $txt;
}


=head2 output_hex_hashref()

Convenience wrapper for C<< { $self->output_hex } >>.

=cut

sub output_hex_hashref {
  my ($self) = @_;
  return { $self->output_hex };
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
    return map {
      my $cls = ref($_);
      my $alg = $_->algorithm;
      $alg2name{$alg}
	or die "Unknown digest $cls($alg)";
    } $self->_hashers;
  }
}


1;
