#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;

use App::StrongHash::DfIndex;

use lib 't/lib';
use Local::TestUtil qw( test_digestfile_name tryerr );


sub main {
  plan tests => 6;
  my $ASDI = 'App::StrongHash::DfIndex';

  # Define short names for the various files
  no warnings 'qw'; # for literal ,
  my %fn =
    qw( s52A test-data-34570e3bd4ef302f7eefc5097d4471cdcec108b9-sha512,sha256
	s3A  test-data-34570e3bd4ef302f7eefc5097d4471cdcec108b9-sha384
	s1o  test-data-3457only-sha1
	s3oB test-data-3457only-sha384-bogus
	s3o  test-data-3457only-sha384 );
  @fn{ keys %fn } = map { test_digestfile_name($_) } values %fn;

  # Simple fetch
  is_deeply([ $ASDI->new_files($fn{s52A})->want_htype(qw( sha256 sha512 ))->lookup(qw( 4029c34c1729940c8e71938fbcd2c787f0081ffe 507bc9769db563824b71e765f8fa59de18a49215 )) ],
	    # for (0hundred cdbdii)
	    [
	     [qw[ f89abec316c5bb09babb3e426c8821a934ebbf689058caf458760159bd6d8b41 23be9da7a21dd87b23be84ba4a2192f69008cb5a0afa4d03f9b87f41ba03876194ce7fce4a66098258aa2ff85bf310263744a9cb9b91fbf405ba5829f4aa183d ]],
	     [qw[ ebde6baba887d10d81c9cf24db15e6a102ca65bbfdf0af8c89d9ca3c48225758 8c971b95cb4470a17a61b1901d5236aa575eb6d8a19cd3cdb3f322f24707db72fb32756e16f9deee27eb6214403333a691ea320321da65def2c9569b4c36457d ]],
	    ], '256,512 * 0hundred,cdbdii');
  like(tryerr { $ASDI->new_files($fn{s52A})->lookup('123') },
       qr{^ERR:need list context at \Q$0}, 'lookup !scalar');

  # Composite fetch
  is_deeply([ $ASDI->new_files(@fn{qw{ s52A s3A }})->want_htype(qw( sha256 sha384 ))->lookup(qw( 4029c34c1729940c8e71938fbcd2c787f0081ffe 507bc9769db563824b71e765f8fa59de18a49215 )) ],
	    # for (0hundred cdbdii)
	    [
	     [qw[ f89abec316c5bb09babb3e426c8821a934ebbf689058caf458760159bd6d8b41 5ce3839fdb60f91b02baf3d095ae52e5889c56ff441fef4b0620b671edb0fa34f9a5cda36587c1686eea81115dc24db1 ]],
	     [qw[ ebde6baba887d10d81c9cf24db15e6a102ca65bbfdf0af8c89d9ca3c48225758 66b9a56f4ea862f40677815e52202c342d6f48eda618723076a3a44876661a746e554f6237152eedeca12dd307392a9c ]],
	    ], '256,384 * 0hundred,cdbdii');

  # Merge fail
  like(tryerr { [ $ASDI->new_files(@fn{qw{ s3oB s3A }})->lookup('34570e3bd4ef302f7eefc5097d4471cdcec108b9') ] },
       qr{^ERR:Disagreement on 34570e3\S+ sha384:ff74ea482bf4\S+e44a868f370c in t/digestfile/\S+-sha384\.stronghash, was sha384:000000002bf4\S+e44a00000000 earlier},
       '34470e: bogus sha384 value found');

  # No-conflict merge
  my $ncm = $ASDI->new_files(@fn{qw{ s3o s3A }});
  is_deeply([ $ncm->want_htype(qw( sha384 ))->lookup('34570e3bd4ef302f7eefc5097d4471cdcec108b9') ],
	    [ [qw[ ff74ea482bf47bcb618d27a5018356b0cf522cc3133e3ab7d03e5085fdfd333f02a570765ee55fdd21a6e44a868f370c ]] ],
	    'no-conflict merge 34570');
  my $ans;
  like(tryerr { $ans = [ $ncm->want_htype(qw( sha384 sha1 ))->lookup('34570e3bd4ef302f7eefc5097d4471cdcec108b9') ] },
       qr{^ERR:No sha1 hash value found for 34570e3bd4ef302f7eefc5097d4471cdcec108b9\b}, 'no-conflict merge lacks sha1')
    or note explain { ans => $ans };

  return 0;
}


exit main();
