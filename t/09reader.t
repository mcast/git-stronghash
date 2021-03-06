#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;

use App::StrongHash::DigestReader;
use App::StrongHash::Git::Objects;

use lib 't/lib';
use Local::TestUtil qw( testdigestfile testrepo_or_skip tryerr t_nxt_wantarray );


sub main {
  my $testrepo = testrepo_or_skip();

  plan tests => 2;

  subtest testrepo_cmp => sub {
    my $objs = App::StrongHash::Git::Objects->new($testrepo);
    $objs->add_all;
    my @objs_gitsha1 = $objs->iter_all()->collect;

    my $df_fh = testdigestfile('test-data-34570e3bd4ef302f7eefc5097d4471cdcec108b9-sha512,sha256');
    my $df = App::StrongHash::DigestReader->new(testdata => $df_fh);
    t_nxt_wantarray($df);
    my %df_hdr = $df->header;
    is_deeply($df_hdr{htype}, [qw[ gitsha1 sha512 sha256 ]], "htypes");
    is_deeply([ $df->htype ], [qw[ gitsha1 sha512 sha256 ]], 'htypes method');
    my @df_hash # list of [ gitsha1, @hash ]
      = $df->nxt;
    t_nxt_wantarray($df);
    push @df_hash, $df->collect;

    t_nxt_wantarray($df);
    is_deeply([ $df->nxt ], [], "df: still eof");

    is_deeply([ map { $_->[0] } @df_hash ],
	      \@objs_gitsha1, 'gitsha1s match')
      or note explain { objs_gitsha1 => \@objs_gitsha1, df_hash => \@df_hash };

    my %no2h; # guru checked output is from git-stronghash-dump, first line
    @no2h{qw{ gitsha1 sha512 sha256 }} =
      qw( 34570e3bd4ef302f7eefc5097d4471cdcec108b9
	  ded4cbf51a43ceac61fa519bc8ec225d126d73c27995971b0fe4d1fec27e4221bc19fc753cd495546a8ea0784b502dc15b263409a62948b7b1ecb96c229eb042
	  ee45e9dfaa2926076d150a782b4753191830276983355316ad99f7571567d594 );
    is_deeply($df->nxtout_to_hash($df_hash[0]),
	      \%no2h, 'nxtout_to_hash[0]');
  };

  like(tryerr { App::StrongHash::DigestReader->new(testdata => 'filename') },
       qr{^ERR:Filehandle filename should be in binmode}, 'wantbinmode');

  return 0;
}


exit main();
