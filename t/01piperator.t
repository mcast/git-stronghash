#!perl -T
use strict;
use warnings FATAL => 'all';

use Test::More;

use App::Git::StrongHash::Piperator;

use lib 't/lib';
use Local::TestUtil qw( tryerr ione plusNL detaint );


sub main {
  plan tests => 15;
  my $AGSP = 'App::Git::StrongHash::Piperator';

  # using taint only to provoke fork failure, so accept any PATH
  $ENV{PATH} = detaint($ENV{PATH});

  { # 4
    my $seq = $AGSP->new(qw( seq 5 15 ));
    my $n = 4;
    my @seq = $seq->collect(\$n);
    is($n, 15, "5..15 len");
    is_deeply(\@seq, plusNL(5 .. 15), "5..15 ele");
    my $L = __LINE__; my $sc_nxt = tryerr { scalar  $seq->nxt };
    like($sc_nxt, qr{^ERR:wantarray! at t/01piperator.t line $L\.$}, 'wantarray || croak');
    like(tryerr { my @n = $seq->nxt },
	 qr{^ERR:not running in 'seq},
	 "5..15 olivertwist");
    like(tryerr { $seq->finish },
	 qr{^ERR:double finish in 'seq},
	 "5..15 close;close");
  }

  is_deeply([ $AGSP->new(qw( seq 1 4 ))->collect ],
	    plusNL(1 .. 4), "1..4 collect");

  my $perl = detaint($^X);

  { # 3
    my $theQ = $AGSP->new($perl, -e => 'print "foo\nbar\n"; exit 42');
    is(ione($theQ), "foo\n", "42: foo");
    is(ione($theQ), "bar\n", "42: bar");
    like(tryerr { my @n = $theQ->nxt },
	 qr{^ERR:command returned 42 in '\S*perl\S* -e print "foo\\nbar\\n"; exit 42'$},
	 "exitcode failure");
  }

  like(tryerr { local $SIG{__WARN__} = sub {}; $AGSP->new('/') },
       qr{ERR:fork failed: Permission denied in '/'},
       "fork failure (bad exe)");

  like(tryerr { local $ENV{PATH} = "$0:$ENV{PATH}"; $AGSP->new('true') },
       qr{^ERR:fork died: Insecure \$ENV\{PATH\} while running }, "fork failure (here due to taint)");

  like(tryerr { $AGSP->new($perl, -e => 'print "moo\n"; kill "INT", $$')->collect },
       qr{^ERR:command killed by SIG2 in '\S*perl\S* -e},
       "kill detection");

  { # 2
    my @w;
    local $SIG{__WARN__} = sub { push @w, "@_" };
    my $L1 = __LINE__; my $drop_it = $AGSP->new('true');
    undef $drop_it;
    my $L2 = __LINE__; # where the DESTROY is seen
    is(scalar @w, 1, "warning on unclosed drop");
    like($w[0],
	 qr{^\[w\] DESTROY before close on 'true' from t/01piperator\.t:$L1 at t/01piperator\.t line $L2\.},
	 "warning shows create");
  }

  { # 1
    my $o = $AGSP->new('true');
    close $o->{fh};
    like(tryerr { $o->finish },
	 qr{^ERR:command close failed: Bad file descriptor in 'true'$},
	 "close failure (due to preclose)");
  }

  return 0;
}


exit main();
