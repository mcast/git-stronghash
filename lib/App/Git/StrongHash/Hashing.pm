package App::Git::StrongHash::Hashing;
use strict;
use warnings;

our @HASHES;
BEGIN { @HASHES = qw( sha1 sha256 sha384 sha512 ) }
use Digest::SHA @HASHES;
