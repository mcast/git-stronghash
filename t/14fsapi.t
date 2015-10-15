#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;
use Digest::SHA;

use App::StrongHash::FsPOSIX;

use lib 't/lib';
use Local::TestUtil qw( testrepo_or_skip tryerr );


sub main {
  my $testrepo = testrepo_or_skip();
  plan tests => 1;

  subtest POSIX => sub {
    my $ASF = 'App::StrongHash::FsPOSIX';
    my $mtdir = "$testrepo/emptydir";

    my $o = $ASF->new($testrepo);
    rmdir $mtdir; # cleanup for use below

    # directories
    my @top = $o->scan;
    is_deeply(\@top,
	      [ map {"$testrepo/$_"}
		qw[ .git/ 0hundred cdbdii d1/ d2/ mtgg ten ]],
	      'test-data top')
      or diag explain { top => \@top };

    like(tryerr { $o->scan('not/exist') },
	 qr{^ERR:scan.*failed: No such file or directory at \Q$0 line },
	 'scan not/exist');
    mkdir $mtdir or die "mkdir $mtdir: $!";
    is_deeply([ $o->scan('emptydir') ], [], 'test-data emptydir');
    rmdir $mtdir or die "rmdir $mtdir: $!";

    # get file
    my $d = Digest::SHA->new('sha256');
    $d->addfile( $o->getfh('d1/fifty') );
    is($d->hexdigest,
       '02d36ee22aefffbb3eac4f90f703dd0be636851031144132b43af85384a2afcd',
       'fh d1/fifty');
    like(tryerr { $o->getfh('nuffink') },
	 qr{^ERR:getfh.*: No such file or directory at \Q$0 line },
	 'getfh nuffink');
  };

  return 0;
}


exit main();
