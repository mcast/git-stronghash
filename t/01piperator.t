#!perl
use strict;
use warnings;
use Test::More;
use Try::Tiny;

use App::Git::StrongHash::Piperator;

sub tryerr(&) {
  my ($code) = @_;
  return try { $code->() } catch {"ERR:$_"};
}

sub main {
  plan tests => 12;

  {
    my $seq = App::Git::StrongHash::Piperator->new(qw( seq 5 15 ));
    my $n = 0;
    my @seq = $seq->collect(\$n);
    is($n, 10, "5..15 len");
    is_deeply(\@seq, [map {"$_\n"} (5 .. 15)], "5..15 ele");
    like(tryerr { my @n = $seq->nxt }, qr{^ERR:double finish}, "5..15 olivertwist");
  }

  {
    my $false = App::Git::StrongHash::Piperator->new('false');
    like(tryerr { my @n = $false->nxt }, qr{nonzero}, "false dies");
  }
}

main();
