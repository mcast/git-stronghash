package App::Git::StrongHash::TreeAdder;
use strict;
use warnings;

use Try::Tiny;

use App::Git::StrongHash::CatFilerator;


=head1 NAME

App::Git::StrongHash::TreeAdder - "git cat-file" consumer for trees

=head1 DESCRIPTION

Used by L<App::Git::StrongHash::Objects> to scan trees.


=head1 CLASS METHOD

=head2 new($repo, $treeh, $blobh)

Use the $repo to create L<App::Git::StrongHash::CatFilerator>s to
stream objects out.  There may be several of these in sequence.

Scanned trees' gitsha1s are added to C<keys %$treeh>, values undef.
Blobs discovered are added to C<<$blobh->{$gitsha1} = $bytesize>>.
Trees which already C<exist> are not scanned.

Returns the object.  No subprocess is started yet.

=cut

sub new {
  my ($class, $repo, $treeh, $blobh) = @_;
  my $self =
    { repo => $repo,
      treeh => $treeh,
      blobh => $blobh };
  bless $self, $class;
  return $self;
}


=head1 OBJECT METHODS

=head2 scantrees($gitsha1s_seed)

Scan the given tree gitsha1s.  It should be an ARRAYref of hex
gitsha1s, whose contents may be emptied or changed.

=cut

sub scantrees {
  my ($self, $trees) = @_;
  my $repo = $self->{repo};
  my $treesi = App::Git::StrongHash::Listerator->new($trees);
  my $cfi = App::Git::StrongHash::CatFilerator->new
    ($repo, $self, $treesi, 'endfile');
  while (my ($n) = $cfi->nxt) {
    # $n
  }
}

=head1 OBJECT METHODS, AS HASHER

Thses are called by the internal
L<App::Git::StrongHash::CatFilerator>.

=head2 newfile($type, $size, $gitsha1)

The parent CatFilerator tells us (as the data consumer, known as
$hasher), of a new Git object.

=head2 add($blk)

The parent CatFilerator gives us a block of data from the most
recently declared L</newfile>.

=head2 endfile()

The parent CatFilerator notifies us of the end of the Git object, and
expects a return value to pass back from its L</nxt>.




1;
