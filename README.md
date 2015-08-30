# Background

There have been discussions about the security of SHA-1 for Git object ids, most famously back in about 2006

* Parts of the Git mailing list thread of 2006/08/27 [Starting to think about sha-256?](http://thread.gmane.org/gmane.comp.version-control.git/26106)
    * [Linus believed](http://thread.gmane.org/gmane.comp.version-control.git/26106/focus=26125) that SHA-1 plus sanitary git-fetch behaviour is enough.

		> Yeah, I don't think this is at all critical, especially since git really on a security level doesn't _depend_ on the hashes being cryptographically secure. As I explained early on (ie over a year ago, back when the whole design of git was being discussed), the _security_ of git actually depends on not cryptographic hashes, but simply on everybody being able to secure their own _private_ repository.
		>
		> So the only thing git really _requires_ is a hash that is _unique_ for the developer (and there we are talking not of an _attacker_, but a benign participant).
		>
		> That said, the cryptographic security of SHA-1 is obviously a real bonus.  So I'd be disappointed if SHA-1 can be broken more easily (and I obviously already argued against using MD5, exactly because generating duplicates of that is fairly easy). But it's not "fundamentally required" in git per se.

    * The proposal implies history-rewriting change on an irregular basis.  [Florian wrote](http://thread.gmane.org/gmane.comp.version-control.git/26106/focus=26204)

		>[...]
		>> Maybe sha-256 could be considered for the next major-rev of git?
		>
		> And in 2008 [ two years from OP -- m ], you'd have to rewrite history again, to use the next "stronger" hash function?

* On the Git mailing list 2005/04/16 [SHA1 hash safety](http://thread.gmane.org/gmane.comp.version-control.git/295),
    * Repository [migration to stronger hashes](http://thread.gmane.org/gmane.comp.version-control.git/295/focus=311) for the objectids is possible,

		> I believe Linus has already stated on this list [ can't find it -- m ] that his plan is to eventually provide a tool for bulk migration of an existing SHA1 git repository to a new hash type.  Basically munging through the repository in bulk, replacing all the hashes.  This seems a perfectly adequate strategy at the moment.

    * but what about all the places in the code, documentation and other web pages pointing in,  which refer to those ids?  For me, it was bad enough when changeset numbers broke upon leaving Subversion.

* On Stackoverflow, [How would git handle a SHA-1 collision on a blob?](http://stackoverflow.com/a/9392525)
* On the value of knowing what should be in the repository, [The Linux Backdoor Attempt of 2003](https://freedom-to-tinker.com/blog/felten/the-linux-backdoor-attempt-of-2003/) (via [TacticalCoder on HN](https://news.ycombinator.com/item?id=7628161))
* [Size of the git sha1 collision attack surface](http://joeyh.name/blog/entry/size_of_the_git_sha1_collision_attack_surface/) via LWN, [Dealing with weakness in SHA-1](https://lwn.net/Articles/337745/)
* On the cost of changing hashing algorithms, [Why Google is Hurrying the Web to Kill SHA-1](https://konklone.com/post/why-google-is-hurrying-the-web-to-kill-sha-1)
* Amusing toys for making hash prefix collisions [beautify_git_hash](https://github.com/vog/beautify_git_hash) and [gitbrute](https://github.com/bradfitz/gitbrute) / [deadbeef](https://github.com/bradfitz/deadbeef/commit/deadbeef) are...  just that.
* Implementation note: when we speak of Git SHA-1 hashes, the reason they don't match the output of [`sha1sum`](https://en.wikipedia.org/wiki/Sha1sum#External_links) upon your file is the header which [`git hash-object`](http://git-scm.com/docs/git-hash-object) prepends.

# The Plan

Based on my interpretation of this, informed by many articles (references now lost),

1. SHA-1 objectids work just fine for identifying objects in a repository where nobody is maliciously inserting data.  So leave them alone.
2. Choose stronger hash(es) to suit - any time you like.  Accept the price of calculating and storing new hashes for everything, and we are untied from SHA-1's security problems.
    * We now have an objectid (gitsha1) hash and a security hash.  They are different values, used for different purposes.
    * The security hashes, plus any signature upon them, need to be stored somewhere.  Git is an object storage system, so we'll use that.
3. Hash everything in the repository and sign the resulting digest.  Maintain this efficiently.
    * Hashes in the digestfile must be full-length for full security, and in binary for efficiency.
    * Don't change a digestfile once it has been written.  Unless the repository history is rewritten, when old digestfiles may become useless.
    * We will accumulate digestfiles.  For incremental signing, it must be possible to rapidly check previous signatures.
4. Use branch namespaces or other types of refs to hold the data.  *Fuzziness here.*
5. Use Git hooks to maintain the digestfiles.  *More fuzziness.*
    * We probably want a digestfile per work session, not per commit.
6. The hashes themselves (whether SHA-1 or something stronger) do nothing to prove the object was not tampered with since it was written (e.g. `git filter-branch`).  Some reinforcement is necessary whatever hash is in use,
    * getting it digitally signed in some reliable way
    * writing the full hash down on paper in your secret code and hiding it under the carpet
    * keeping the repository secure, so that nobody but you can push objects into it or change the refs
7. If/when the chosen hashes are devalued, repeat the process with newer hashes.
    * Naturally, any new timestamp signatures made with new hashes cannot be backdated to match the age of the weakening ones.
    * Refreshing the hash type while the old one is merely suspect, rather than known to be broken, might lend some weight to the old signature files.  They would demonstrably (by the new hash) have been in existence at that point in time before public attacks were known on the old hash.

## Advantages
* Simple design
* Retro-fit to any Git repo, or probably any other hash-based object storage system.
* No need to change commitids, ever.
* When properly integrated, should free the object store from many of the obvious security concerns with ageing hash algorithms.
* No window for "tricked into using older weaker protocol" attacks.

## Disadvantages
* Not integrated with Git core, except by whatever hooks may be available.
* Security is given to history "later", not during push of individual commits.
* Performance isn't going to be great until some parts are replaced.
* It is possible to construct a commit (of >65535 new objects) which cannot be stored in one digestfile.  (The limit could be removed by declaring 0xFFFF as unbounded, but then indexing such files becomes a special case.)

## Current state

* [0.01](https://github.com/mcast/git-stronghash/releases/tag/0.01) can [dump a file](https://github.com/mcast/git-stronghash/commit/56b081522d854be9084470b23ad72880a35723cd) containing SHA-256es of everything in this project so far.  I [got it signed](http://virtual-notary.org/log/ac20e7eb-b833-4b59-92e9-9ef069e63373/) manually.

## Open Questions

* Should the file format be more generic?  Rename the project?
    * I renamed all "objid" or "objectid" to "gitsha1" to make this easier.
    * Digestfiles store the type of the objectid, so could be used for other hash types.
    * I can think of other collections of files I might want to sign incrementally.
    * Maybe I should just put those files in a git / git-annex repository.
    * Other VC systems might want the same solution to this problem.  They would need their own objectid collection and digestfile stashing, but otherwise code can be shared.

# Local vapourware queue

* [ ] The licence!  Either GPLv3 (my prejudice) or same-terms-as-Git, undecided.
* [ ] Iterator for digestfile body --> are these commits present? --> if yes, are their trees and blobs?
* [ ] Iterator for treeful of digestfiles
* [ ] Support submodule (commit object in tree).  `TODO: Ignoring submodule \'160000 commit 34570e3bd4ef302f7eefc5097d4471cdcec108b9 - test-data\' at ...`
* [ ] Teach App::StrongHash::Git::Objects to subtract already-hashed objects
* [ ] Notice when A:G:SH:Objects discovers new objects which relate only to the previous signature, and defer
* [ ] Stream digestfiles directly into some other ref namespace
* [ ] Machinery to get these signed by something from time to time

```
git grep -nE 'TO[D]O' | perl -i -e 'undef $/; $todo=<STDIN>; $todo =~ s{^README.*\n}{}mg; $_=<>; s{^(## in-source\n).*?\n\n}{$1\x60\x60\x60\n$todo\x60\x60\x60\n\n}ms; print' README.md
```
## in-source
```
lib/App/StrongHash/DfLister.pm:24:TODO: Extend args.  May need to index by another column.  May want to index only commits.
lib/App/StrongHash/Git/Objects.pm:102:TODO: Currently we assume this is a full clone with a work-tree, but this probably isn't necessary.
lib/App/StrongHash/Git/Objects.pm:104:TODO: should find topdir, and check it's actually a git_dir
lib/App/StrongHash/Git/Objects.pm:106:TODO: consider git rev-list instead, sure to be faster, probably better control of commit boundaries
lib/App/StrongHash/Git/Objects.pm:107:TODO: speed test on a known-size repo; (current dbix-class, sha256) ==[ 28m on MBP(2.5GHz Core i5) ]=> 2913KiB digestfile
lib/App/StrongHash/Git/Objects.pm:132:# TODO: feeding @arg via a splicing pushable iterator would simplify add_trees greatly
lib/App/StrongHash/Git/Objects.pm:189:    # TODO:OPT not sure we need all this data now, but it's in the commitblob anyway
lib/App/StrongHash/Git/Objects.pm:211:TODO:OPT Here, on the first pass before any hashing has been done, there will be double-reading of tree info because we'll hash it later
lib/App/StrongHash/Git/Objects.pm:264:# TODO: add_treecommit - submodules, subtrees etc. not yet supported in add_trees
lib/App/StrongHash/Git/Objects.pm:265:# TODO: add_stash, add_reflog - evidence for anything else that happens to be kicking around
lib/App/StrongHash/Git/Objects.pm:266:# TODO:   git fsck --unreachable --dangling --root --tags --cache --full --progress  --verbose 2>&1 # should list _everything_ in repo
lib/App/StrongHash/Git/Objects.pm:280:  my $ntag = $self->iter_tag->dcount; # TODO:OPT more code, less memory?
lib/App/StrongHash/Git/Objects.pm:376:    # TODO: why push commits/tags/trees/blobs down different CatFilerator instances when one iterator could do the lot?  Well I was thinking about object types and parallelism when I wrote it, but since each comes out with its type the parallelism can be further in anyway.
lib/App/StrongHash/Git/TreeAdder.pm:50:      treeci_ignored => {}, # TODO: delete later
lib/App/StrongHash/Git/TreeAdder.pm:154:      warn "TODO: Ignoring submodule '$mode commit $hexid .../$leaf'\n"
lib/App/StrongHash/ObjHasher.pm:196:    unshift @{ $out{htype} }, 'gitsha1';  # TODO:HTYPE remove when filev=1 gone
lib/App/StrongHash/ObjHasher.pm:296:     comment => 'n/c', # TODO: add API for optional comment
lib/App/StrongHash/Piperator.pm:42:# TODO: new_later : defer via a Laterator
lib/App/StrongHash/Piperator.pm:43:# TODO: new_parallel : parallelising would be neat, useful for hashing step, maybe as a Forkerator not under Piperator?
t/00compile.t:68:  { local $TODO = 'rsn'; fail('check A:SH:: does not refer to A:SH:G::'); }
t/07objhasher.t:38:    grep { $_ ne 'gitsha1' } # TODO:HTYPE remove when we can hash with it again
t/08catfile.t:45:      local $TODO = 'early _cleanup would be nice';
t/08catfile.t:68:    ok(!-f $tmp_fn, "tmpfile gone (eof)"); # TODO: move this up, we could _cleanup after first object returns
t/08catfile.t:76:  local $TODO = 'L8R';
t/11bigproj.t:41:      sub { my $msg = "@_"; warn $msg unless $msg =~ /^TODO:/ };
t/11bigproj.t:54:  local $TODO = 'break up objects into 64k units';
t/12treeadder.t:75:     "TODO: Ignoring submodule '160000 commit 3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a \.\.\./testrepo'\n",
```

# Contributing

Really? Cool!

The Github issue tracker is neat for pull requests, but I would rather keep bugs and feature requests in this file for now.

Imagine that some nice friendly welcome, rules about respecting people and ownership of changes were `#include`d here from some other respectable project.
