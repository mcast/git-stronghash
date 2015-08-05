#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;

use App::Git::StrongHash::Iterator; # for the benefit of 00compile.t
use App::Git::StrongHash::Listerator;

use lib 't/lib';
use Local::TestUtil qw( tryerr ione t_nxt_wantarray );


sub main {
  plan tests => 11;
  my $AGSL = 'App::Git::StrongHash::Listerator';

  my @N = qw( one two three four five six seven eight nine );

  my $iter = $AGSL->new(@N);
  t_nxt_wantarray($iter);
  is_deeply([ $iter->collect ], \@N, "simple");

  my @copy = @N;
  $iter = $AGSL->new(\@copy);
  is_deeply([ $iter->collect ], \@N, "listref");
  is(scalar @N, 9, '@N preserved');
  is(scalar @copy, 0, '@copy consumed');

  @copy = reverse @N;
  is_deeply([ $iter->collect ], [ reverse @N ], "collect again, listmod");

  $iter = $AGSL->new('one for the coverage');
  is(($iter->nxt)[0], 'one for the coverage', 'single item');

  my @in = ([ "not" ], [ "recommended" ]);
  my $dont = [ @in ];
  $iter = $AGSL->new($dont);
  my @out = $iter->collect;
  is_deeply(\@out, \@in, "twolist matches");
  $in[0][0] = 'THIS';
  @{$in[1]} = qw( IS WHY );
  is_deeply(\@out, [ [ 'THIS' ], [qw[ IS WHY ]] ], "twolist remains linked")
    or diag explain { in => \@in, out => \@out, dont => $dont, iter => $iter };

  $iter = $AGSL->new(("Bob") x 1000);
  cmp_ok($iter->dcount, '==', 1000, "dcount");
  is_deeply([ $iter->nxt ], [], "dcount empties");

  return 0;
}


exit main();
