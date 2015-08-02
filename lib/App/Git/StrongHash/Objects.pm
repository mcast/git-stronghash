package App::Git::StrongHash::Objects;
use strict;
use warnings;

use App::Git::StrongHash::Piperator;
use App::Git::StrongHash::Listerator;


=head1 NAME

App::Git::StrongHash::Objects - enumerate relevant Git objects

=head1 DESCRIPTION

The basic plan is to enumerate all repository objects, hash them up
and get them signed with something.

=head2 For efficient storage of signatures

=over 4

=item * objects should be hashed and signed just once

Store (blobid, hashes) for each, in one file per signing run.  Hashes
should be fixed length in one file, and the header will tell what they
are.

The blobid identifies the data Git intended to store - commitid,
treehash or whatever.  The hashes collectively lock the actual
contents at the time of hash to that blobid.

There is no value in hashing and signing again, unless with different
algoritms.

=item * resulting data file is never changed

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
useful to put them early in the signature file for faster reading.

=back

Unfortunately this may mean holding every commitid in memory for a
while, and handling the old signatures of every object.

For large repos, it may be worth stashing

=over 4

=item * a bloom filter of blobids

To avoid the wasted time of chasing for new objects through every old
signature file.

=item * a list of still-in-use blobid which were found in older
signatures

(abbreviated-blobid, signature-number, file-offset) would do it for
8+8+8=24 bytes apiece; or 6+4+2=12 with more time-wasting collisions
and a limit of 64k objects/signature.  File offset can be a blobcount
rather than bytecount.

This would permit fast and safe verification of sign-once, because the
signer isn't relying only on the cache be correct.

=back


=head1 CLASS METHODS

=head2 new($git_dir)

XXX: Currently we assume this is a full clone with a work-tree, but this probably isn't necessary.

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
  my $nulz = (@arg && $arg[0] eq '-z:') ? shift @arg : 0;
  if (@arg) {
    my $iter = App::Git::StrongHash::Piperator->new(@cmd, @arg);
    $iter->irs("\x00") if $nulz;
    return $iter;
  } else {
    return @cmd;
  }
}

# XXX: feeding @arg via a splicing pushable iterator would simplify add_trees greatly
sub _git_many {
  my ($self, $subcmd, $n_up, @arg) = @_;
  my @iter;
  while (@arg) {
    my @chunk = splice @arg, 0, $n_up;
    push @iter, $self->_git(@$subcmd, @chunk);
  }
  return App::Git::StrongHash::Penderator->new(@iter);
}


=head1 OBJECT METHODS

=head2 add_tags()

List into this object the current tags and their designated commits.
Return self.

=cut

sub add_tags {
  my ($self) = @_;
  my $tags = $self->{tag} ||= {}; # refs/foo => tagid or commitid
  my $showtags = $self->_git(qw( show-ref --tags ))->
    # Sample data - blobids are abbreviated here for legibility
    # 4ef2c940 refs/tags/fif
    # d9101db5 refs/tags/goldfish
    # 9385c934 refs/tags/goldfish^{}   # NOT, unless --dereference
    iregex(qr{^(\w+)\s+(\S+)$}, "Can't read tagid,tagref");
  while (my ($nxt) = $showtags->nxt) {
    my ($tagid, $tagref) = @$nxt;
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
    # XXX:OPT not sure we need all this data now, but it's in the commitblob anyway
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

XXX:OPT Here, on the first pass before any hashing has been done, there will be double-reading of tree info because we'll hash it later

=cut

sub add_trees {
  my ($self) = @_;
  my $trees = $self->{tree} ||= {}; # treeid => undef, a set of trees scanned
  my $blobs = $self->{blob} ||= {}; # blobid => size, a set of blobids known
  my @treeq =
    grep { !exists $trees->{$_} }
    values %{ $self->{ci_tree} };

  while (@treeq) {
    my %scanned;
    @scanned{ splice @treeq } = ();
    my $ls_tree = $self->_git_many([qw[ -z: ls-tree -r -t -l --full-tree -z ]], 1, keys %scanned)->
      # mcra@peeplet:~/gitwk-github/git-stronghash/test-data/d1$ git ls-tree -r -t -l --full-tree -z ae5349e7 | perl -pe 's/\x00/\n/g'
      # 040000 tree 5c1e1d7e049f5201eff7c3ca43c405f38564b949       -	d2
      # 100644 blob 03c56aa7f2f917ff2c24f88fd1bc52b0bab7aa17      12	d2/shopping.txt
      # 100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391       0	mtgg
      # 100644 blob f00c965d8307308469e537302baa73048488f162      21	ten
      iregex(qr{^\s*([0-7]{6}) (tree|blob) ([0-9a-f]+)\s+(-|\d+)\t(.+)\x00},
	     "Can't read lstree(mode,type,objid,size,name)");
    while (my ($nxt) = $ls_tree->nxt) {
      my ($mode, $type, $objid, $size, $name) = @$nxt;
      # type: tree | blob, via regex
      if ($type eq 'tree') {
	next if exists $trees->{$objid};
	next if exists $scanned{$objid}; # uncoverable branch true (too tricky to arrange, and only a shortcut)
	push @treeq, $objid;

      } else {
	if ($type eq 'blob') { # uncoverable branch false (last case, weird structure for 'impossible')

	  $blobs->{$objid} = $size;
	
	} else {
	  die "ls-tree gave me unexpected $type"; # uncoverable statement
	  # and the iregex let it through
	}
      }
    }
    @{$trees}{ keys %scanned } = ();
  }
  return $self;
}

# XXX: add_treecommit - submodules, subtrees etc. not yet supported in add_trees
# XXX: add_stash, add_reflog - evidence for anything else that happens to be kicking around
# XXX:   git fsck --unreachable --dangling --root --tags --cache --full --progress  --verbose 2>&1 # should list _everything_ in repo


=head2 iter_tag()

=head2 iter_ci()

=head2 iter_tree()

=head2 iter_blob()

Return L<App::Git::StrongHash::Listerator> containing sorted objectids
of the requested type.

=cut

sub iter_tag {
  my ($self) = @_;
  my $tags = $self->{tag};
  my $cit = $self->{ci_tree};
  return $self->_mkiter([ grep { !exists $cit->{$_} } values %$tags ]);
}

sub iter_ci {
  my ($self) = @_;
  my $cit = $self->{ci_tree};
  return $self->_mkiter([ keys %$cit ]);
}

sub iter_tree {
  my ($self) = @_;
  return $self->_mkiter([ keys %{ $self->{tree} } ]);
}

sub iter_blob {
  my ($self) = @_;
  return $self->_mkiter([ keys %{ $self->{blob} } ]);
}

sub _mkiter {
  my ($self, $list) = @_;
  @$list = sort @$list;
  return App::Git::StrongHash::Listerator->new($list);
}


sub pipe_one { # incomplete - just some ideas
  my ($self,
      $pipe, # source of this is not yet clear, probably _mkiter($hasher)
      $chunk,
      $hasher, # on our iterator?
     ) = @_;
  $chunk ||= 128*1024;

  # git cat-file --batch='%(objectname) %(objecttype) %(objectsize)' < objids.txt
  # emits
  #   <sha1> SP <type> SP <size> LF
  #   <contents> LF
  # or
  #   <object> SP missing LF
  $pipe->irs("\n");
  my ($line) = $pipe->nxt;
  return () unless defined $line;
  my ($objid, $type, $size) = $line =~ m{^(\S+) (\S+) (\d+)$} or
    die "cat-file parse fail on $line";
  my $blksize = $chunk;
  $pipe->irs(\$size);
  my $blk;
  while ($size >= $chunk) {
    ($blk) = $pipe->nxt;
    die "early end" unless defined $blk;
    $hasher->add(\$blk);
  }
  if ($size > 0) {
    $blksize = $size;
    ($blk) = $pipe->nxt;
    die "early end" unless defined $blk;
    $hasher->add(\$blk);
  }
  $pipe->irs("\n");
  ($blk) = $pipe->nxt;
  $blk = '[eof]' unless defined $blk;
  die "object unterminated ($blk)" unless $blk eq "\n";
}


=head2 blobtotal()

Return (total_byte_size, blob_count) in list context, or just
total_byte_size in scalar context, of all known data blobids as
returned by L</iter_blob>.

Tells nothing of the size of tags, commits or trees; these are
presumed to be "small".

=cut

sub blobtotal {
  my ($self) = @_;
  my $blobs = $self->{blob};
  my ($num, $tot) = (0, 0);
  while (my (undef, $size) = each %$blobs) {
    $tot += $size;
    $num ++;
  }
  return wantarray ? ($tot, $num) : $tot;
}


1;
