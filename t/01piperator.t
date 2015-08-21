#!perl -T
use strict;
use warnings FATAL => 'all';

use Test::More;

use App::Git::StrongHash::Piperator;

use lib 't/lib';
use Local::TestUtil qw( tryerr ione plusNL detaint t_nxt_wantarray );


sub main {
  plan tests => 14;
  my $AGSP = 'App::Git::StrongHash::Piperator';

  # using taint only to provoke fork failure, so accept any PATH
  $ENV{PATH} = detaint($ENV{PATH});

  { # 4
    my $seq = $AGSP->new(qw( seq 5 15 ));
    my $n = 4;
    my @seq = $seq->collect(\$n);
    is($n, 15, "5..15 len");
    is_deeply(\@seq, plusNL(5 .. 15), "5..15 ele");
    t_nxt_wantarray($seq);
    like(tryerr { my @n = $seq->nxt },
	 qr{^ERR:command has finished in 'seq},
	 "5..15 olivertwist");
    like(tryerr { $seq->finish },
	 qr{^ERR:double finish in 'seq},
	 "5..15 close;close");
  }

  cmp_ok($AGSP->new(qw( seq 20 40 ))->dcount, '==', 21, "dcount");

  is_deeply([ $AGSP->new(qw( seq 1 4 ))->collect ],
	    plusNL(1 .. 4), "1..4 collect");

  my $perl = detaint($^X);

  subtest perl_boom => sub {
    my $theQ = $AGSP->new($perl, -e => 'print "foo\nbar\n"; exit 42');
    ok(!$theQ->started, 'wait-for-it');
    my $L;
    is(tryerr { $L = __LINE__; $theQ->finish },
       "ERR:Not yet started at $0 line $L.\n",
       'finish before start');
    is(ione($theQ), "foo\n", "42: foo");
    ok($theQ->started, 'it went');
    is(ione($theQ), "bar\n", "42: bar");
    like(tryerr { my @n = $theQ->nxt },
	 qr{^ERR:command returned 42 in '\S*perl\S* -e print "foo\\nbar\\n"; exit 42'$},
	 "exitcode failure");
    ok($theQ->started, 'still started after exit');
  };

  like(tryerr { local $SIG{__WARN__} = sub {}; $AGSP->new('/')->start },
       qr{ERR:fork failed: Permission denied in '/'},
       "fork failure (bad exe)");

  like(tryerr { local $ENV{PATH} = "$0:$ENV{PATH}"; $AGSP->new('true')->start },
       qr{^ERR:fork died: Insecure \$ENV\{PATH\} while running }, "fork failure (here due to taint)");

  like(tryerr { $AGSP->new($perl, -e => 'print "moo\n"; kill "INT", $$')->collect },
       qr{^ERR:command killed by SIG2 in '\S*perl\S* -e},
       "kill detection");

  { # 2
    my @w;
    local $SIG{__WARN__} = sub { push @w, "@_" };
    my $L1 = __LINE__; my $drop_it = $AGSP->new('true')->start;
    undef $drop_it;
    my $L2 = __LINE__; # where the DESTROY is seen
    is(scalar @w, 1, "warning on unclosed drop");
    like($w[0],
	 qr{^\[w\] DESTROY before close on 'true' from t/01piperator\.t:$L1 at t/01piperator\.t line $L2\.},
	 "warning shows create");
  }

  { # 1
    my $o = $AGSP->new('true')->start;
    close $o->{fh};
    like(tryerr { $o->finish },
	 qr{^ERR:command close failed: Bad file descriptor in 'true'$},
	 "close failure (due to preclose)");
  }

  return 0;
}


exit main();
