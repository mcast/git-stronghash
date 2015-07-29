package Local::TestUtil;
use strict;
use warnings FATAL => 'all';

use App::Git::StrongHash::Piperator;

use Try::Tiny;
use base 'Exporter';

our @EXPORT_OK = qw( ione plusNL tryerr mkiter detaint );


sub tryerr(&) {
  my ($code) = @_;
  return try { $code->() } catch {"ERR:$_"};
}

sub ione {
  my ($iter) = @_;
  my @i = $iter->nxt;
  fail("expected one, got none") unless @i;
  return $i[0]; # (conflates undef and eof)
}

sub plusNL { [ map {"$_\n"} @_ ] }

sub mkiter {
  my (@ele) = @_;
  # a simple list iterator would be fine as input, but there isn't one yet
  return App::Git::StrongHash::Piperator->new($^X, -e => 'foreach my $e (@ARGV) { print "$e\n" }', @ele);
}

sub detaint {
  my ($in) = @_;
  $in =~ m{^(.*)\z}s or die "untaint fail: $in";
  return $1;
}


1;
