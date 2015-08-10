# Background

There have been discussions about the security of SHA-1 for Git object ids, most famously back in about 2006
* http://kerneltrap.org/mailarchive/git/2006/8/27/211001 or [via the marvellous and handy Wayback Machine](https://web.archive.org/web/20090131233821/http://kerneltrap.org/mailarchive/git/2006/8/27/211001)

# The Plan

1. SHA-1 objectids work just fine for identifying objects in a repository where nobody is maliciously inserting data.  So leave them alone.
2. SHA-1 or stronger objectids do nothing to prove the object was not tampered with (e.g. `git filter-branch`) since it was written, anyway.  So some reinforcement is necessary whatever hash is in use.
3. Git provides hooks, branch namespaces and other types of refs.  There is room to maintain extra data here.
4. Hash everything in the repository and sign the result.  Maintain this efficiently.
    * Choose hash(es) to suit.  By paying the price of hashing everything again, we are untied from SHA-1.
    * Hold the hash data compactly without compromising security.  Hashes are stored full-length in binary.
    * Don't change it once it has been written.
    * For incremental signing, it must be possible to rapidly check previous signatures.

## Current state

* 0.01 can [dump a file](https://github.com/mcast/git-stronghash/commit/56b081522d854be9084470b23ad72880a35723cd) containing SHA-256es of everything in this project so far.  I [got it signed](http://virtual-notary.org/log/ac20e7eb-b833-4b59-92e9-9ef069e63373/) manually.

# Local vapourware queue

* [ ] The licence!  Either GPLv3 (my prejudice) or same-terms-as-Git, undecided.
* [ ] Support submodule (commit object in tree).  `Can't read lstree(mode,type,objid,size,name): q{160000 commit 34570e3bd4ef302f7eefc5097d4471cdcec108b9       -  test-data} !~ qr{(?^:^\s*([0-7]{6}) (tree|blob) ([0-9a-f]+)\s+(-|\d+)\t(.+)\x00)} at INST/lib/perl5/App/Git/StrongHash/Objects.pm line 228.`
* [ ] Defer subprocess start, else we get so many `[w] DESTROY before close on 'git ...` warnings upon failure that the error message is swamped.
* [X] `git grep -E TO[D]O` comments from source to here
* [ ] Teach App::Git::StrongHash::Objects to subtract already-hashed objects
* [ ] Notice when A:G:SH:Objects discovers new objects which relate only to the previous signature, and defer
* [ ] Stream digestfiles directly into some other ref namespace
* [ ] Machinery to get these signed by something from time to time

```
git grep -nE 'TO[D]O' | perl -i -e 'undef $/; $todo=<STDIN>; $_=<>; s{^(## in-source\n).*?\n\n}{$1$todo\n}ms; print' README.md
```
## in-source
README.md:36:lib/App/Git/StrongHash/ObjHasher.pm:245:     comment => 'n/c', # TODO: add API for optional comment
README.md:37:lib/App/Git/StrongHash/Objects.pm:99:TODO: Currently we assume this is a full clone with a work-tree, but this probably isn't necessary.
README.md:38:lib/App/Git/StrongHash/Objects.pm:101:TODO: should find topdir, and check it's actually a git_dir
README.md:39:lib/App/Git/StrongHash/Objects.pm:126:# TODO: feeding @arg via a splicing pushable iterator would simplify add_trees greatly
README.md:40:lib/App/Git/StrongHash/Objects.pm:158:    # TODO:UNTESTED If there are no tags, "git show-ref --tags" returns 1 with no text.  We need some output, just ignore it.
README.md:41:lib/App/Git/StrongHash/Objects.pm:183:    # TODO:OPT not sure we need all this data now, but it's in the commitblob anyway
README.md:42:lib/App/Git/StrongHash/Objects.pm:205:TODO:OPT Here, on the first pass before any hashing has been done, there will be double-reading of tree info because we'll hash it later
README.md:43:lib/App/Git/StrongHash/Objects.pm:216:  my %treeci_ignored; # TODO: delete later
README.md:44:lib/App/Git/StrongHash/Objects.pm:238:        warn "TODO: Ignoring submodule '$mode $type $objid $size $name'"
README.md:45:lib/App/Git/StrongHash/Objects.pm:257:# TODO: add_treecommit - submodules, subtrees etc. not yet supported in add_trees
README.md:46:lib/App/Git/StrongHash/Objects.pm:258:# TODO: add_stash, add_reflog - evidence for anything else that happens to be kicking around
README.md:47:lib/App/Git/StrongHash/Objects.pm:259:# TODO:   git fsck --unreachable --dangling --root --tags --cache --full --progress  --verbose 2>&1 # should list _everything_ in repo
README.md:48:lib/App/Git/StrongHash/Objects.pm:273:  my $ntag = $self->iter_tag->dcount; # TODO:OPT more code, less memory?
README.md:49:lib/App/Git/StrongHash/Objects.pm:349:    # TODO: why push commits/tags/trees/blobs down different CatFilerator instances when one iterator could do the lot?  Well I was thinking about object types and parallelism when I wrote it, but since each comes out with its type the parallelism can be further in anyway.
README.md:50:lib/App/Git/StrongHash/Piperator.pm:41:# TODO: new_later : defer via a Laterator
README.md:51:lib/App/Git/StrongHash/Piperator.pm:42:# TODO: new_parallel : parallelising would be neat, useful for hashing step, maybe as a Forkerator not under Piperator?
README.md:52:t/04app.t:15:    local $TODO = 'write the app and script stub parts';
README.md:53:t/08catfile.t:44:      local $TODO = 'early _cleanup would be nice';
README.md:54:t/08catfile.t:67:    ok(!-f $tmp_fn, "tmpfile gone (eof)"); # TODO: move this up, we could _cleanup after first object returns
README.md:55:t/08catfile.t:73:  local $TODO = 'L8R';
lib/App/Git/StrongHash/ObjHasher.pm:245:     comment => 'n/c', # TODO: add API for optional comment
lib/App/Git/StrongHash/Objects.pm:99:TODO: Currently we assume this is a full clone with a work-tree, but this probably isn't necessary.
lib/App/Git/StrongHash/Objects.pm:101:TODO: should find topdir, and check it's actually a git_dir
lib/App/Git/StrongHash/Objects.pm:126:# TODO: feeding @arg via a splicing pushable iterator would simplify add_trees greatly
lib/App/Git/StrongHash/Objects.pm:158:    # TODO:UNTESTED If there are no tags, "git show-ref --tags" returns 1 with no text.  We need some output, just ignore it.
lib/App/Git/StrongHash/Objects.pm:183:    # TODO:OPT not sure we need all this data now, but it's in the commitblob anyway
lib/App/Git/StrongHash/Objects.pm:205:TODO:OPT Here, on the first pass before any hashing has been done, there will be double-reading of tree info because we'll hash it later
lib/App/Git/StrongHash/Objects.pm:216:  my %treeci_ignored; # TODO: delete later
lib/App/Git/StrongHash/Objects.pm:238:        warn "TODO: Ignoring submodule '$mode $type $objid $size $name'"
lib/App/Git/StrongHash/Objects.pm:257:# TODO: add_treecommit - submodules, subtrees etc. not yet supported in add_trees
lib/App/Git/StrongHash/Objects.pm:258:# TODO: add_stash, add_reflog - evidence for anything else that happens to be kicking around
lib/App/Git/StrongHash/Objects.pm:259:# TODO:   git fsck --unreachable --dangling --root --tags --cache --full --progress  --verbose 2>&1 # should list _everything_ in repo
lib/App/Git/StrongHash/Objects.pm:273:  my $ntag = $self->iter_tag->dcount; # TODO:OPT more code, less memory?
lib/App/Git/StrongHash/Objects.pm:349:    # TODO: why push commits/tags/trees/blobs down different CatFilerator instances when one iterator could do the lot?  Well I was thinking about object types and parallelism when I wrote it, but since each comes out with its type the parallelism can be further in anyway.
lib/App/Git/StrongHash/Piperator.pm:41:# TODO: new_later : defer via a Laterator
lib/App/Git/StrongHash/Piperator.pm:42:# TODO: new_parallel : parallelising would be neat, useful for hashing step, maybe as a Forkerator not under Piperator?
t/04app.t:15:    local $TODO = 'write the app and script stub parts';
t/08catfile.t:44:      local $TODO = 'early _cleanup would be nice';
t/08catfile.t:67:    ok(!-f $tmp_fn, "tmpfile gone (eof)"); # TODO: move this up, we could _cleanup after first object returns
t/08catfile.t:73:  local $TODO = 'L8R';

# Contributing

Really? Cool!

The Github issue tracker is neat for pull requests, but I would rather keep bugs and feature requests in this file for now.

Imagine that some nice friendly welcome, rules about respecting people and ownership of changes were `#include`d here from some other respectable project.
