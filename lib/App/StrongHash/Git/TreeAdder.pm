package App::StrongHash::Git::TreeAdder;
use strict;
use warnings;

use Try::Tiny;
use Carp;

use App::StrongHash::Listerator;
use App::StrongHash::Git::CatFilerator;


=head1 NAME

App::StrongHash::Git::TreeAdder - "git cat-file" consumer for trees

=head1 DESCRIPTION

Used by L<App::StrongHash::Git::Objects> to scan trees.


=head1 CLASS METHOD

=head2 new($repo, $treeh, $blobh)

Use the $repo to create L<App::StrongHash::Git::CatFilerator>s to
stream objects out, per L</scantrees> call.

=over 3

=item * Scanned trees' gitsha1s are added to C<keys %$treeh>, values
undef.

=item * Blobs discovered are added to C<<$blobh->{$gitsha1} = $bytesize>>.

Except we don't ask for the blob sizes, so we're leaving them undef.

=item * Trees which already C<exist> are not scanned.

=back

Returns the object.  No subprocess is started yet.

=cut

sub new {
  my ($class, $repo, $treeh, $blobh) = @_;
  my $self =
    { repo => $repo,
      treeh => $treeh,
      treeci_ignored => {}, # TODO: delete later
      blobh => $blobh };
  bless $self, $class;
  return $self;
}


=head1 OBJECT METHODS

=head2 scantrees($gitsha1s_seed)

Scan the given tree gitsha1s.

$gitsha1s_seed should be an ARRAYref of hex gitsha1s for trees.  The
list contents may be emptied or changed.

Returns a list of tree gitsha1 that have been discovered but not yet
scanned.

=cut

sub scantrees {
  my ($self, $trees) = @_;
  my $repo = $self->{repo};
  my $blobh = $self->{blobh};
  my $treeh = $self->{treeh};
  for (my $i=0; $i<@$trees; $i++) {
    next unless exists $treeh->{ $trees->[$i] };
    splice @$trees, $i, 1;
    $i--;
  }
  my @scan = @$trees;
  my $treesi = App::StrongHash::Listerator->new($trees);
  my $cfi = App::StrongHash::Git::CatFilerator->new
    ($repo, $self, $treesi, 'endfile');
  my %scan_later;
  while (my ($n) = $cfi->nxt) {
    # $n is output of L</endfile>
    my ($newblobs, $newtrees) = @$n;
    @{$blobh}{ @$newblobs } = (); # we don't know bloblengths
    @scan_later{ @$newtrees } = ();
  }
  @{$treeh}{@scan} = ();
  delete @scan_later{ keys %$treeh };
  return keys %scan_later;
}


=head1 OBJECT METHODS, AS HASHER

Thses are called by the internal
L<App::StrongHash::Git::CatFilerator>.

=head2 newfile($type, $size, $gitsha1)

The parent CatFilerator tells us (as the data consumer, known as
$hasher), of a new Git object.

=head2 add($blk)

The parent CatFilerator gives us a block of data from the most
recently declared L</newfile>.

=head2 endfile()

The parent CatFilerator notifies us of the end of the Git object, and
expects a return value to pass back from its L</nxt>.

This decodes the binary tree object.  The logic is here because C<git
ls-tree> has no --batch mode, while C<git cat-file> does.  It may be a
liability...

=cut

sub newfile {
  my ($self, $type, $size, $gitsha1) = @_;
  confess "require tree, got $type $gitsha1" unless $type eq 'tree';
  $self->{obj} = '';
  $self->{tree} = $gitsha1; # for messages
  return;
}

sub add {
  my ($self, $blk) = @_;
  $self->{obj} .= $blk;
  return;
}

sub endfile {
  my ($self) = @_;
  my $obj = delete $self->{obj};
  my $l = length($obj);
  return [ [], [] ] if $l == 0;
  my (@blob, @tree);
  while ($obj =~ m{\G(\d{5,6}) ([^\x00]+)\x00(.{20})}cgs) {
    my ($mode, $leaf, $binid) = ($1, $2, $3);
    my $hexid = unpack('H40', $binid);
    if ($mode =~ /^100(?:644|755)$/) {
      push @blob, $hexid;
    } elsif ($mode =~ /^0?40000$/) {
      push @tree, $hexid;
    } elsif ($mode eq '120000') {
      push @blob, $hexid; # symlink
    } elsif ($mode eq '160000') {
      warn "TODO: Ignoring submodule '$mode commit $hexid .../$leaf'\n"
	unless $self->{treeci_ignored}{"$hexid:$leaf"}++;
    } else {
      my $tree = $self->{tree};
      die "Unknown object mode '$mode $leaf $hexid' in $tree";
    }
  }
  my $p = pos($obj);
  if ($p != $l) {
    my $tree = $self->{tree};
    confess "Parse fail on tree $tree at offset $p of $l";
  }
  return [ \@blob, \@tree ];
}


1;
