#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;

use App::Git::StrongHash::DigestReader;

use lib 't/lib';
use Local::TestUtil qw( testdigestfile testrepo_or_skip tryerr t_nxt_wantarray );


sub main {
  my $testrepo = testrepo_or_skip();

  plan tests => 2;

  subtest testrepo_cmp => sub {
    my $objs = App::Git::StrongHash::Objects->new($testrepo);
    $objs->add_all;
    my @objs_gitsha1 = $objs->iter_all()->collect;

    my $df_fh = testdigestfile('test-data-34570e3bd4ef302f7eefc5097d4471cdcec108b9');
    my $df = App::Git::StrongHash::DigestReader->new(testdata => $df_fh);
    t_nxt_wantarray($df);
    my %df_hdr = $df->header;
    is_deeply($df_hdr{htype}, [qw[ gitsha1 sha512 sha256 ]], "htypes");
    my @df_hash # list of [ gitsha1, @hash ]
      = $df->nxt;
    t_nxt_wantarray($df);
    push @df_hash, $df->collect;

    t_nxt_wantarray($df);
    is_deeply([ $df->nxt ], [], "df: still eof");

    is_deeply([ map { $_->[0] } @df_hash ],
	      \@objs_gitsha1, 'gitsha1s match')
      or note explain { objs_gitsha1 => \@objs_gitsha1, df_hash => \@df_hash };
  };

  like(tryerr { App::Git::StrongHash::DigestReader->new(testdata => 'filename') },
       qr{^ERR:Filehandle filename should be in binmode}, 'wantbinmode');

  return 0;
}


exit main();
