package App::StrongHash::Iterator;
use strict;
use warnings;

use App::StrongHash::Regexperator;
use App::StrongHash::Penderator;


=head1 NAME

App::StrongHash::Iterator - superclass for the app's iterators

=head1 DESCRIPTION

These classes are the usual iterator pattern, implemented without
dependencies (or if you prefer, while on holiday away from network).


=head1 OBJECT METHODS

=head2 collect(\$n)

=head2 collect()

Slurp the remaining elements of the iterator into a list and return
that list (as normal for list or scalar context).

Optionally, count the elements with C<$n++>.

=cut

sub collect {
  my ($self, $nref) = @_;
  $nref = do { my $n=0; \$n } unless $nref;
  my @out;
  while (my @nxt = $self->nxt) {
    push @out, @nxt;
    $$nref ++;
  }
  return @out;
}


=head2 dcount()

Destructive count: consume the remaining elements of the iterator and
return how many there were.

=cut

sub dcount {
  my ($self) = @_;
  my $n = 0;
  while (my @nxt = $self->nxt) {
    $n ++;
  }
  return $n;
}


=head2 prepend(@iter)

=head2 append(@iter)

Create and return an L<App::StrongHash::Penderator> instance from this
iterator and the others specified, either putting this one last
(prepend) or first (append).

=cut

sub prepend {
  my ($self, @iter) = @_;
  return App::StrongHash::Penderator->new(@iter, $self);
}

sub append {
  my ($self, @iter) = @_;
  return App::StrongHash::Penderator->new($self, @iter);
}


=head2 iregex($regex, $errmsg)

Create and return an L<App::StrongHash::Regexperator>.
C<$errmsg> is optional.

=cut

sub iregex {
  my ($self, @arg) = @_;
  return App::StrongHash::Regexperator->new($self, @arg);
}


1;
