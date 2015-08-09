use 5.008;
use ExtUtils::MakeMaker;
use strict;
use warnings;

WriteMakefile
  (NAME         => 'App::Git::StrongHash',
   VERSION_FROM => 'lib/App/Git/StrongHash.pm',
   PREREQ_PM    =>
   {
    'Try::Tiny' => 0,
    'File::Slurp' => 0,
    'YAML' => 0,
   },
   TEST_REQUIRES =>
   {
    'Test::MockObject' => 0,
   },
   EXE_FILES => [qw[ script/git-stronghash-all ]],
   ABSTRACT     => 'App::Git::StrongHash provides git-stronghash which adds secure hashing to repository contents',
   AUTHOR     => 'Matthew Astley <mcast@cpan.org>');
