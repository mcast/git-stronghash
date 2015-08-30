package App::StrongHash::Penderator;
use strict;
use warnings;

use Carp;

use parent 'App::StrongHash::Iterator';


=head1 NAME

App::StrongHash::Penderator - append & prepend iterators

=head1 DESCRIPTION

Iterator concatenation.

=head1 CLASS METHODS

=head2 new(@iter)

Create L<App::StrongHash::Iterator> with specified sub-iterators
concatenated in the given order.

=cut

sub new {
  my ($class, @iter) = @_;
  my $self = { iter => \@iter };
  bless $self, $class;
  return $self;
}


=head2 nxt()

In list context, call L<App::StrongHash::Iterator/nxt> on the
sub-iterators in order until they are empty.

Returns the fetched element, or nothing at the end.

=cut

sub nxt {
  my ($self) = @_;
  croak "wantarray!" unless wantarray;
  my $iters = $self->{iter};
  while (my ($iter) = @$iters) {
    my $n = my @ele = $iter->nxt;
    if ($n) {
      return @ele;
    } else {
      shift @$iters;
    }
  }
  return ();
}

1;
