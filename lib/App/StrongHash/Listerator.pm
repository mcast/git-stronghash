package App::StrongHash::Listerator;
use strict;
use warnings;

use Carp;

use parent 'App::StrongHash::Iterator';


=head1 NAME

App::StrongHash::Listerator - list-based iterator

=head1 DESCRIPTION

Iterate a list.

=head1 CLASS METHODS

=head2 new($listref)

=head2 new(@list)

Create L<App::StrongHash::Iterator> with specified contents.
Items will be C<shift>ed off the left.  If a listref is used, no
copying is done and the pending elements can be modified.

=cut

sub new {
  my ($class, @lst) = @_;
  my $self = { lst => \@lst };
  ($self->{lst}) = @lst if 1 == @lst && ref($lst[0]) eq 'ARRAY';
  bless $self, $class;
  return $self;
}


=head2 nxt()

In list context, take C<$list[0]>.

Returns the fetched element, or nothing at the end.

=cut

sub nxt {
  my ($self) = @_;
  croak "wantarray!" unless wantarray;
  my $lst = $self->{lst};
  return shift @$lst if @$lst;
  return ();
}


=head2 dcount()

As for L<App::StrongHash::Iterator/count> but faster.

=cut

sub dcount {
  my ($self) = @_;
  my $n = @{ $self->{lst} };
  @{ $self->{lst} } = ();
  return $n;
}


1;
