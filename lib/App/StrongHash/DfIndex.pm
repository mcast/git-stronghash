package App::StrongHash::DfIndex;
use strict;
use warnings;

use Carp;

use App::StrongHash::DfLister;
use App::StrongHash::DigestReader;


=head1 NAME

App::StrongHash::DfIndex - tell which digestfile has requested object

=head1 DESCRIPTION

Currently, scans a collection of digestfiles in order to return
lookups from them.

TODO: Later it should probably build an index as required.

TODO: More ways to give a collection of digestfiles.


=head1 CLASS METHODS

=head2 new_files(@fn)

Create from filenames of digestfiles.  (Caller should do any directory
recursion and file extension matching.)

=cut

sub new_files {
  my ($class, @fn) = @_;
  my $self = { fn => \@fn };
  bless $self, $class;
  return $self;
}


=head1 OBJECT METHODS

=head2 want_htype(@htype)

Specify the htypes wanted from the input digestfiles.  Returns $self.

=cut

sub want_htype {
  my ($self, @htype) = @_;
  $self->{htype} = \@htype;
  return $self;
}


sub _scan {
  my ($self, @for) = @_;
  my %scanfor;
  @scanfor{@for} = ();
  foreach my $fn (@{ $self->{fn} }) {
    my $dfl = $self->{dflist}{$fn} ||= $self->_lister($fn);
    $dfl->whittle(\%scanfor, 1) if @for;
#    last if @for && !keys %scanfor; # we know enough to give an answer # TODO: could take this shortcut again iff we see we will satisfy want_htype
  }
  return;
}

sub _lister {
  my ($self, $fn) = @_;
  open my $fh, '<', $fn or die "Open $fn for reading: $!";
  binmode $fh or die "binmode($fn): $!";
  return App::StrongHash::DfLister->new($fn => $fh);
}

sub _dreader {
  my ($self, $fn) = @_;
  open my $fh, '<', $fn or die "Open $fn for reading: $!";
  binmode $fh or die "binmode($fn): $!";
  return App::StrongHash::DigestReader->new($fn => $fh);
}


=head2 lookup(@objid)

Look up each objid and return a list of hash values matching the names
set in L</want_htype> for each input objectid.

Where the object is not found, or hashes of the requested type are
missing from the file, generate an error.

TODO: Allow lax treatment of errors (return undefs + issue warnings?)

TODO: Currently, it's an error if no htypes are set.  Could return hashref of whatever is available.

TODO: Only works on full-length objectids, but should perhaps be more helpful.

TODO: Uses two passes, where one would be enough for a one-call-many-objids lookup.  Perhaps a tee iterator, or just a tap on DfLister?

=cut

sub lookup {
  my ($self, @objid) = @_;
  croak "need list context" unless wantarray;
  $self->_scan(@objid);

  my %read_in; # fn => @obj
  while (my ($fn, $dflist) = each %{ $self->{dflist} }) {
    push @{ $read_in{$fn} }, grep { $dflist->find($_) } @objid;
  }

  my %find;
  @find{ @objid } = ();
  my ($idxkey, $ik_fn, $fn);
  my $merge = sub {
    my ($h) = @_;
    my $objid = delete $h->{$idxkey};
    if (defined $find{$objid}) {
      my $f = $find{$objid};
      while (my ($t, $v) = each %$h) {
	if (defined $f->{$t}) {
	  die "Disagreement on $objid $t:$v in $fn, ".
	    "was $t:$$f{$t} earlier" # we didn't record old $fn
	    unless $f->{$t} eq $v;
	} else {
	  $f->{$t} = $v;
	}
      }
    } else {
      $find{$objid} = $h;
    }
  };

  while (($fn, my $objs) = each %read_in) {
    my $dfr = $self->_dreader($fn);
    my ($dfr_ik) = $dfr->htype;
    if (defined $idxkey) {
      die "Index key mismatch: expected $idxkey from $ik_fn, found $dfr_ik in $fn"
	unless $dfr_ik eq $idxkey;
    } else {
      ($idxkey, $ik_fn) = ($dfr_ik, $fn);
    }
    while (my ($n) = $dfr->nxt) {
      next unless exists $find{$n->[0]};
      $merge->( $dfr->nxtout_to_hash($n) );
    }
  }

  my @htype = @{ $self->{htype} || [] }
    or die "Please set want_htype before lookup";
  my @out = map {
    my @a;
    foreach my $t (@htype) {
      my $h = $find{$_}{$t};
      push @a, $h;
      die "No $t hash value found for $_" unless defined $h;
    }
    \@a;
  } @objid;
  return @out;
}


1;
