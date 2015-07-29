#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;

use App::Git::StrongHash::Penderator;

use lib 't/lib';
use Local::TestUtil qw( mkiter tryerr plusNL ione t_nxt_wantarray );


sub main {
  plan tests => 5;
  my $AGSJ = 'App::Git::StrongHash::Penderator';

  my @w;
  local $SIG{__WARN__} = sub {
    my ($msg) = @_;
    return if $msg =~ /DESTROY before close/; # expect many of these, dull
    push @w, $msg;
  };

  my @N = qw( one two three four five six seven eight nine );
  my @i;
  my $mki = sub {
    @i = ( mkiter(@N[0, 1, 2]),
	   mkiter(@N[3, 4, 5]),
	   mkiter(@N[6, 7, 8]));
  };

  my $iter = $AGSJ->new($mki->());
  is_deeply([ $iter->collect ], plusNL(@N), "join(3 x 3)");

  $mki->();
  $iter = $AGSJ->new($i[0], $i[1])->append($i[2]);
  t_nxt_wantarray($iter);
  is_deeply([ $iter->collect ], plusNL(@N), "join(AB)->append(C)");

  $mki->();
  $iter = $i[0]->append($i[1], $i[2]);
  is_deeply([ $iter->collect ], plusNL(@N), "A->append(BC)");

  $mki->();
  $iter = $i[2]->prepend($i[0], $i[1]);
  is_deeply([ $iter->collect ], plusNL(@N), "C->prepend(AB)");


  return 0;
}


exit main();
