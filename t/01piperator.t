#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;
use Try::Tiny;

use App::Git::StrongHash::Piperator;

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

sub main {
  plan tests => 8;

  { # 4
    my $seq = App::Git::StrongHash::Piperator->new(qw( seq 5 15 ));
    my $n = 4;
    my @seq = $seq->collect(\$n);
    is($n, 15, "5..15 len");
    is_deeply(\@seq, plusNL(5 .. 15), "5..15 ele");
    like(tryerr { my @n = $seq->nxt },
	 qr{^ERR:not running in 'seq},
	 "5..15 olivertwist");
    like(tryerr { $seq->finish },
	 qr{^ERR:double finish in 'seq},
	 "5..15 close;close");
  }

  is_deeply([ App::Git::StrongHash::Piperator->new(qw( seq 1 4 ))->collect ],
	    plusNL(1 .. 4), "1..4 collect");

  { # 3
    my $theQ = App::Git::StrongHash::Piperator->new($^X, -e => 'print "foo\nbar\n"; exit 42');
    is(ione($theQ), "foo\n", "42: foo");
    is(ione($theQ), "bar\n", "42: bar");
    like(tryerr { my @n = $theQ->nxt },
	 qr{^ERR:command returned 42 in '\S*perl\S* -e print "foo\\nbar\\n"; exit 42'$},
	 "exitcode failure");
  }
}

main();
