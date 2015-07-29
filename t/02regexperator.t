#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;

use App::Git::StrongHash::Regexperator;

use lib 't/lib';
use Local::TestUtil qw( mkiter tryerr plusNL ione t_nxt_wantarray );


sub main {
  plan tests => 10;
  my $AGSR = 'App::Git::StrongHash::Regexperator';

  my @w;
  local $SIG{__WARN__} = sub {
    my ($msg) = @_;
    return if $msg =~ /DESTROY before close/; # expect many of these, dull
    push @w, $msg;
  };

  { # 2
    my $seq = $AGSR->new( mkiter(qw( foo bar baz )), qr{[aeiou]}, "no vowel");
    t_nxt_wantarray($seq);
    is_deeply([ $seq->collect ], plusNL(qw(foo bar baz)), "match nocapture");
  }

  { # 2
    my $L1;
    my $seq = $AGSR->new( mkiter(qw( foo bar )), qr{fump}, "MSVerr");
    like(tryerr { $L1 = __LINE__; $seq->collect },
	 qr{^ERR:MSVerr: q\{foo\n\} !~ qr\{\S*fump\S*\} at t/02\S+ line $L1\.$}, "no match message");
    $seq = $AGSR->new(mkiter(qw( foo bar )), qr{fump});
    like(tryerr { $seq->collect },
	 qr{^ERR:No match: q\{foo\n\} !~}, "no match default");
  }

  { # 1
    my $seq = $AGSR->new(mkiter(qw( foo bar baz )), qr{([aeiou]+)});
    is_deeply([ $seq->collect ], [qw[ oo a a ]], "vowels");
  }

  { # 4
    my $seq = $AGSR->new(mkiter(qw( foo bar baz )), qr{([aeiou]+)(.?)});
    is_deeply(ione($seq), [ 'oo', '' ], 'foo');
    is_deeply(ione($seq), [ 'a', 'r' ], 'bar');
    is_deeply(ione($seq), [ 'a', 'z' ], 'baz');
    is_deeply([ $seq->nxt ], [], 'end');
  }

  is_deeply([ $AGSR->new(mkiter(qw( 1 2 3 )), qr{^([a-z])?})->collect ],
	    [ (undef) x 3 ], # from the non-matching first capture
	    'weird case for branch coverage');

  return 0;
}


exit main();
