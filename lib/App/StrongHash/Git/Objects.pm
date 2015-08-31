package App::StrongHash::Git::Objects;
use strict;
use warnings;

use File::Temp 'tempfile';
use Carp;

use App::StrongHash::Piperator;
use App::StrongHash::Git::CatFilerator;
use App::StrongHash::Listerator;
use App::StrongHash::ObjHasher;
use App::StrongHash::Git::TreeAdder;
use App::StrongHash::Regexperator;
use App::StrongHash::DfLister;


=head1 NAME

App::StrongHash::Git::Objects - enumerate relevant Git objects

=head1 DESCRIPTION

The basic plan is to enumerate all repository objects, hash them up
and get them signed with something.

=head2 For efficient storage of signatures

=over 4

=item * objects should be hashed and signed just once

Store (blobid, hashes) for each, in one digestfile per signing run.
Hashes should be fixed length in one file, and the header will tell
what they are.

The blobid identifies the data Git intended to store - commitid,
treehash or whatever.  The hashes collectively lock the actual
contents at the time of hash to that blobid.

There is no value in hashing and signing again, unless with different
algoritms.

=item * resulting digestfile is never changed

Packfile deltify is very good, but why make work for it?

=item * total number of such files impacts the treesize to list them

...and each tree must be stored, so this should scale as a fraction of
the total commit count, or be stored in a part/ial_num/bering_scheme
of directories.

=back

=head2 For efficient incremental signing

=over 4

=item * Each later commit is likely to reuse many objects

We should assume a need to examine all previous signatures to perform
"hash just once".

=item * Commits already signed do not need to be re-examined

Each signature will list some (commitid, hashes) sets anyway.

We can use those to subtract from the total commit list.  It would be
useful to put them early in the digestfile for faster reading.

=back

Unfortunately this may mean holding every commitid in memory for a
while, and handling the old signatures of every object.

For large repos, it may be worth stashing

=over 4

=item * a bloom filter of blobids

To avoid the wasted time of chasing for new objects through every old
digestfile.

=item * a list of still-in-use blobid which were found in older
signatures

(abbreviated-blobid, digestfile-number, file-offset) would do it for
8+8+8=24 bytes apiece; or 6+4+2=12 with more time-wasting collisions
and a limit of 64k objects/signature.  File offset can be a blobcount
rather than bytecount.

This enables fast and safe verification of sign-once.  The signer
isn't relying only on the cache to be correct.

=back


=head1 CLASS METHODS

=head2 new($git_dir)

TODO: Currently we assume this is a full clone with a work-tree, but this probably isn't necessary.

TODO: should find topdir, and check it's actually a git_dir

TODO: consider git rev-list instead, sure to be faster, probably better control of commit boundaries
TODO: speed test on a known-size repo; (current dbix-class, sha256) ==[ 28m on MBP(2.5GHz Core i5) ]=> 2913KiB digestfile

=cut

sub new {
  my ($class, $dir) = @_;
  my $self = { dir => $dir };
  bless $self, $class;
  return $self;
}

sub _git {
  my ($self, @arg) = @_;
  my $dir = $self->{dir};
  my @cmd = ("git", "--work-tree", $dir, "--git-dir", "$dir/.git");
  my $nulz = (@arg && $arg[0] eq '-z:') # unused since 6e8083e2 (TreeAdder)
    ? shift @arg : 0;
  if (@arg) {
    my $iter = App::StrongHash::Piperator->new(@cmd, @arg);
    $iter->irs($nulz ? "\x00" : "\n");
    return $iter;
  } else {
    return @cmd;
  }
}

# TODO: feeding @arg via a splicing pushable iterator would simplify add_trees greatly
# used only once..?!
sub _git_many {
  my ($self, $subcmd, $n_up, @arg) = @_;
  my @iter;
  while (@arg) {
    my @chunk = splice @arg, 0, $n_up;
    push @iter, $self->_git(@$subcmd, @chunk);
  }
  return App::StrongHash::Penderator->new(@iter);
}


=head1 OBJECT METHODS

=head2 add_tags()

List into this object the current tags and their designated commits.
Return self.

=cut

sub add_tags {
  my ($self) = @_;
  my $tags = $self->{tag} ||= {}; # refs/foo => tagid or commitid
  my $showtags = $self->_git(qw( show-ref --tags --heads ))->
    # Sample data - blobids are abbreviated here for legibility
    # 4ef2c940 refs/tags/fif
    # d9101db5 refs/tags/goldfish
    # 9385c934 refs/tags/goldfish^{}   # NOT, unless --dereference
    iregex(qr{^(\w+)\s+(\S+)$}, "Can't read tagid,tagref");
  while (my ($nxt) = $showtags->nxt) {
    my ($tagid, $tagref) = @$nxt;
    # If there are no tags, older "git show-ref --tags" returns 1 with no text.  We need some output, just ignore it.
    next if $tagref =~ m{^HEAD$|^refs/heads/};
    $tags->{$tagref} = $tagid;
  }
  return $self;
}

=head2 add_commits()

List into this object the current commits from C<--all> refs, and
collect their treeids.  Returns self.

There is not yet any optimisation for avoiding known commits.
Extra information is requested and not stored, for easier debugging.

=cut

sub add_commits {
  my ($self) = @_;
  my $cit   = $self->{ci_tree} ||= {}; # commitid => treeid
  my @maybe_dele = grep { !defined $cit->{$_} } keys %$cit;
  push @maybe_dele, values %{ $self->{tag} ||= {} };
  # git log --all brings all current refs, but may have been given deleted tags+commitids
  my $ciinfo = $self->_git_many
    ([qw[ log --format=%H%x09%T%x09%P%x09%x23%x20%cI%x20%d%x20%s ]], 20, '--all', @maybe_dele)->
    # TODO:OPT not sure we need all this data now, but it's in the commitblob anyway
    # Sample data - blobids are abbreviated here for legibility
    # 34570e3b	8f0cc215	5d88f523 f81423b6 9385c934	# 2015-07-30T22:14:27+01:00  (HEAD, brA) Merge branch 'brB', tag 'goldfish' into brA
    # 9385c934	89a7d23f	f40b4bd2	# 2015-07-26T17:21:57+01:00  (tag: goldfish) magoldfish
    # f81423b6	ae5349e7	b1ef447c	# 2015-07-26T16:37:25+01:00  (origin/brB, brB) wacky shopping
    # 5d88f523	18860e20	4ef2c940	# 2015-07-26T16:33:25+01:00  (origin/brA, origin/HEAD, smoosh) seq -w 1 100
    #...
    # d537baf1	4b825dc6		# 2015-07-26T16:29:36+01:00  initial empty commit
    iregex(qr{^(\w+)\t(\w+)\t+([0-9a-f ]*)\t# (.*)$}, "Can't read ciid,treeid,parents,info");
  while (my ($nxt) = $ciinfo->nxt) {
    my ($ci, $tree, $parentci, $time_refs_subject__for_debug) = @$nxt;
    $cit->{$ci} = $tree unless defined $cit->{$ci};
  }
  return $self;
}


=head2 add_trees()

List into this object the contents of all known trees, recursing to
collect subtrees and blobids.  Returns self.

TODO:OPT Here, on the first pass before any hashing has been done, there will be double-reading of tree info because we'll hash it later

=cut

sub add_trees {
  my ($self) = @_;
  my $trees = $self->{tree} ||= {}; # treeid => undef, a set of trees scanned
  my $blobs = $self->{blob} ||= {}; # blobid => size, a set of blobids known
  my @treeq =
    grep { !exists $trees->{$_} }
    values %{ $self->{ci_tree} };
  my $scanner = App::StrongHash::Git::TreeAdder->new($self, $trees, $blobs);
  while (@treeq) {
    @treeq = $scanner->scantrees(\@treeq);
  }

  # Now fill in sizes of blobs
  my ($fh, $filename) = tempfile('gitblobids.txt.XXXXXX', TMPDIR => 1);
  {
    local $\ = "\n"; # ORS
    while (my ($id, $size) = each %$blobs) {
      next if defined $size;
      print {$fh} $id or die "printing to $filename: $!";
    }
    close $fh or die "closing $filename: $!";
  }
  my $sizer = $self->_git(qw( cat-file --batch-check ));
  $sizer->start_with_STDIN($filename);
  $sizer = App::StrongHash::Regexperator->new
    ($sizer, qr{^([0-9a-f]{40}) blob (\d+)\n},
     'unexpected output from "git cat-file --batch-check of blobs"');
  while (my ($n) = $sizer->nxt) {
    my ($objid, $size) = @$n;
    $blobs->{$objid} = $size;
  }

  return $self;
}


=head2 add_all()

Convenience method calls L</add_tags>, L</add_commits> and
L</add_trees> in turn.  Returns $self.

=cut

sub add_all {
  my ($self) = @_;
  return $self->add_tags->add_commits->add_trees;
}


# TODO: add_treecommit - submodules, subtrees etc. not yet supported in add_trees
# TODO: add_stash, add_reflog - evidence for anything else that happens to be kicking around
# TODO:   git fsck --unreachable --dangling --root --tags --cache --full --progress  --verbose 2>&1 # should list _everything_ in repo

=head2 mkhasher(%info)

Calls L<App::StrongHash::ObjHasher/new> and returns the new object.
Values for C<nci, nblob, blobbytes, nobj> are provided and will
replace those in C<%info>.

=cut

sub mkhasher {
  my ($self, %info) = @_;
  $info{nci} = scalar keys %{ $self->{ci_tree} };
  my $ntree  = scalar keys %{ $self->{tree} };
  my $ntag = $self->iter_tag->dcount; # TODO:OPT more code, less memory?
  @info{qw{ blobbytes nblob }} = $self->blobtotal;
  $info{nobj} = $info{nci} + $info{nblob} + $ntree + $ntag;
  return App::StrongHash::ObjHasher->new(%info);
}


=head2 iter_all(@arg)

Return an L<App::StrongHash::Iterator> which runs across all the
gitsha1 ids.

C<@arg> may be

=over 4

=item () # no arguments,

Return L<App::StrongHash::Listerator> of sorted gitsha1 objectids of
the requested type.

=item (bin => $hasher)

When passed an L<App::StrongHash::ObjHasher>, return an Iterator which
will read the objects from disk and send them to the ObjHasher in
turn, yielding the C<output_bin> from each in order.

=item (txt => $hasher)

After passing objects to the ObjHasher, return C<<scalar $hasher->output_hex >>.

=item (hash => $hasher)

After passing objects to the ObjHasher, return C<<{ $hasher->output_hex } >>.

=back

=cut

sub iter_all {
  my ($self, @arg) = @_;
  return App::StrongHash::Penderator->new
    ($self->iter_ci(@arg),
     $self->iter_tag(@arg),
     $self->iter_tree(@arg),
     $self->iter_blob(@arg));
}


=head2 iter_tag

=head2 iter_ci

=head2 iter_tree

=head2 iter_blob

These create the individual L<App::StrongHash::Iterator>s which
L</iter_all> uses, and take the same C<@arg>.

=cut

sub iter_tag {
  my ($self, @arg) = @_;
  my $tags = $self->{tag};
  my $cit = $self->{ci_tree};
  return $self->_mkiter([ grep { !exists $cit->{$_} } values %$tags ], @arg);
}

sub iter_ci {
  my ($self, @arg) = @_;
  my $cit = $self->{ci_tree};
  return $self->_mkiter([ keys %$cit ], @arg);
}

sub iter_tree {
  my ($self, @arg) = @_;
  return $self->_mkiter([ keys %{ $self->{tree} } ], @arg);
}

sub iter_blob {
  my ($self, @arg) = @_;
  return $self->_mkiter([ keys %{ $self->{blob} } ], @arg);
}

sub _mkiter {
  my ($self, $list, @arg) = @_;
  @$list = sort @$list;
  my $iter = App::StrongHash::Listerator->new($list);
  if (!@arg) {
    return $iter;
  } elsif (2 == @arg) {
    my ($mode, $hasher) = @arg;
    my %mconv = (qw( txt output_txt  hash output_txtsref  bin output_bin ));
    my $method = $mconv{$mode}
      or croak "Unknown mode iter_*(@arg)";
    # TODO: why push commits/tags/trees/blobs down different CatFilerator instances when one iterator could do the lot?  Well I was thinking about object types and parallelism when I wrote it, but since each comes out with its type the parallelism can be further in anyway.
    return App::StrongHash::Git::CatFilerator->new
      ($self, $hasher, $iter, $method);
  } else {
    croak "Unknown modetype iter_*(@arg)";
  }
}


=head2 blobtotal()

Return (total_byte_size, blob_count) in list context, or just
total_byte_size in scalar context, of all known data blobids as
returned by L</iter_blob>.

Tells nothing of the size of tags, commits or trees; these are
presumed to be "small".

Total_byte_size is now most likely undef, since switching to
L<App::StrongHash::Git::TreeAdder>.

=cut

sub blobtotal {
  my ($self) = @_;
  my $blobs = $self->{blob};
  my ($num, $tot) = (0);
  while (my (undef, $size) = each %$blobs) {
    $tot += $size if defined $size;
    $num ++;
  }
  return wantarray ? ($tot, $num) : $tot;
}


=head2 mkdigesfile($fh, $hasher)

Write to C<$fh> the header and body of the digestfile representing all
objects discovered by the C<add_*> methods.  Returns nothing.  Caller
opens and closes the file.

=cut

sub mkdigesfile {
  my ($self, $fh, $hasher) = @_;
  App::StrongHash::ObjHasher->wantbinmode($fh);
  my $stream = $self->iter_all(bin => $hasher);
  print {$fh} $hasher->header_bin or die "Writing header failed: $!";
  while (my @nxt = $stream->nxt) {
    print {$fh} $nxt[0] or die "Writing body failed: $!";
  }
  return;
}


=head2 subtract_seen($dflister)

Remove from this collection of objects-to-scan some which have already
been seen.  Return $self.

This should be done after relevant C<add_*> methods have been called.
Internal state is modified, as if the objects in C<$dflister> had not
been seen.

=cut

sub subtract_seen {
  my ($self, $dfl) = @_;
  foreach my $h (@{$self}{qw{ ci_tree tree blob tag }}) {
    $dfl->whittle($h, 1); # remove seen
  }
  return $self;
}


1;
