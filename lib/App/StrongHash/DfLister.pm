package App::StrongHash::DfLister;
use strict;
use warnings;

use Carp;

use App::StrongHash::DigestReader;


=head1 NAME

App::StrongHash::DfLister - build set of objectid from digestfile

=head1 DESCRIPTION

Iterate the digestfile, keeping the gitsha1s as keys in a hash.

=head1 CLASS METHODS

=head2 new(@arg)

C<@arg> are as for L<App::StrongHash::DigestReader>.

TODO: Extend args.  May need to index by another column.  May want to index only commits.

=cut

sub new {
  my ($class, @arg) = @_;
  my $dfr = App::StrongHash::DigestReader->new(@arg);
  my $self = { dfr => $dfr };
  bless $self, $class;
  return $self;
}


=head1 OBJECT METHODS

=head2 slurp()

Trigger the reading of the file (in one go).  Also happens
automatically when needed.  Don't call it twice!  Returns $self.

=cut

sub slurp {
  my ($self) = @_;
  my %objid;
  my $dfr = $self->_dfr;
  while (my ($n) = $dfr->nxt) {
    $objid{ $n->[0] } = undef;
  }
  $self->{objid} = \%objid;
  return $self;
}

sub _dfr {
  my ($self) = @_;
  return $self->{dfr};
}

sub _objid {
  my ($self) = @_;
  $self->slurp unless $self->{objid};
  return $self->{objid};
}


=head2 find(@objid)

Return 0 or 1 for each @objid.

Only works on full-length objectids.

=cut

sub find {
  my ($self, @objid) = @_;
  my $o = $self->_objid;
  for (my $i=0; $i<@objid; $i++) {
    $objid[$i] = exists $o->{ $objid[$i] } ? 1 : 0;
  }
  if (wantarray) {
    return @objid;
  } else {
    return $objid[0] if 1 == @objid;
    croak "need list context for multiple objid";
  }
}


=head2 whittle($hashref, $exist)

Remove from C<%$hashref> the elements which are (when $exist is true)
or are not (when $exist is false) in the digestfile.  Return $hashref.

Only works on full-length objectids.

=cut

sub whittle {
  my ($self, $hashref, $exist) = @_;
  croak 'Set $exist true to keep unseens, false to keep the hashed'
    unless defined $exist;
  my $o = $self->_objid;
  if ($exist) {
    while (my ($k) = each %$hashref) {
      delete $hashref->{$k} if exists $o->{$k};
    }
  } else {
    while (my ($k) = each %$hashref) {
      delete $hashref->{$k} unless exists $o->{$k};
    }
  }
  return $hashref;
}


=head2 all()

Return ARRAYref of all objectids from the file, without sorting.

=cut

sub all {
  my ($self) = @_;
  return [ keys %{ $self->_objid } ];
}


=head2 forget(\@objid)

=head2 forget(\%set)

Remove the array elements or hash keys from the internal state, as if
they had not been read from the digestfile during L</slurp>.

Returns $self.

There is currently no inverse operation, it is used for testing.  IDs
must be given with full length.  IDs listed but not found are ignored.

=cut

sub forget {
  my ($self, $some) = @_;
  my $objid = $self->_objid;
  if (ref($some) eq 'ARRAY') {
    delete @{$objid}{@$some};
  } else {
    delete @{$objid}{keys %$some};
  }
  return $self;
}


1;
