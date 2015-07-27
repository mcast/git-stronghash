package App::Git::StrongHash::Regexperator;
use strict;
use warnings;

use Carp;

use parent 'App::Git::StrongHash::Iterator';


sub new {
  my ($class, $iter, $regex, $errmsg) = @_;
  my $self =
    { iter => $iter,
      regex => $regex,
      errmsg => $errmsg };
  bless $self, $class;
  return $self;
}

sub nxt {
  my ($self) = @_;
  croak "wantarray!" unless wantarray;
  my $n = (my $in) = $self->{iter}->nxt;
  my $re = $self->{regex};
  if ($n) {
    my $m = my @m = $in =~ $re;
    my $errmsg = $self->{errmsg};
    die "$errmsg: q{$in} !~ $re" unless $m;
    return \@m;
  } else {
    return ();
  }
}

1;
