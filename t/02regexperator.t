#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;
use Try::Tiny;

use App::Git::StrongHash::Piperator;
use App::Git::StrongHash::Regexperator;

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
    my $L = __LINE__; my $sc_nxt = tryerr { scalar  $seq->nxt };
    like($sc_nxt, qr{^ERR:wantarray! at t/02regexperator.t line $L\.$}, 'wantarray || croak');
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
}

main();
