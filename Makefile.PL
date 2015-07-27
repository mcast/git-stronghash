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
   },
   ABSTRACT     => 'App::Git::StrongHash provides git-stronghash which provides secure hashing of repository contents',
   AUTHOR     => 'Matthew Astley <mcast@cpan.org>');