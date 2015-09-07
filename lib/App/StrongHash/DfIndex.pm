package App::StrongHash::DfIndex;
use strict;
use warnings;

use Carp;

use App::StrongHash::DigestReader;
use App::StrongHash::DfLister;


=head1 NAME

App::StrongHash::DfIndex - tell which digestfile has requested object

=head1 DESCRIPTION

Currently, scans a collection of digestfiles in order to return
lookups from them.

TODO: Later it should probably build an index as required.

TODO: More ways to give a collection of digestfiles.


=head1 CLASS METHODS

=head2 new_files(@fn)

Create from filenames of digestfiles.

=cut

sub new_files {
  my ($class, @fn) = @_;
  my $self = { fn => $dfr };
  bless $self, $class;
  return $self;
}


=head1 OBJECT METHODS

=head2 want_htype(@htype)

Specify the htypes wanted from the input digestfiles.  Returns $self.

Currently, it's an error if none are set.  Something more opporunistic
would be possible.

=cut

sub want_htype {
  my ($self, @htype) = @_;
  $self->{htype} = \@htype;
  return $self;
}


=head2 lookup(@objid)

Look up each objid and return...?

TODO: Only works on full-length objectids, but should perhaps be more helpful.

=cut

sub lookup {
  my ($self, @objid) = @_;
  return die 'what?';
}


1;
