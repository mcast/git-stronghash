package App::Git::StrongHash::Iterator;
use strict;
use warnings;


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

1;
