package App::Git::StrongHash::Iterator;
use strict;
use warnings;

sub collect {
  my ($self, $nref) = @_;
  $nref ||= \0;
  my @out;
  while (my @nxt = $self->nxt) {
    push @out, @nxt;
    $nref ++;
  }
  return @out;
}

1;
