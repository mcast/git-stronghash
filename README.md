# Background

There have been discussions about the security of SHA-1 for Git object ids, most famously back in about 2006
* http://kerneltrap.org/mailarchive/git/2006/8/27/211001 or [via the marvellous and handy Wayback Machine](https://web.archive.org/web/20090131233821/http://kerneltrap.org/mailarchive/git/2006/8/27/211001)

# The Plan

1. SHA-1 objectids work just fine for identifying objects in a repository where nobody is maliciously inserting data.  So leave them alone.
2. SHA-1 or stronger objectids do nothing to prove the object was not tampered with (e.g. `git filter-branch`) since it was written, anyway.  So some reinforcement is necessary whatever hash is in use.
3. Git provides hooks, branch namespaces and other types of refs.  There is room to maintain extra data here.
4. Hash everything in the repository and sign the result.  Maintain this efficiently.
    * Hold the hash data compactly.
    * Don't change it once it has been written.
    * For incremental signing, it must be possible to rapidly check previous signatures.

# Local vapourware queue

* [ ] Support submodule (commit object in tree).  `Can't read lstree(mode,type,objid,size,name): q{160000 commit 34570e3bd4ef302f7eefc5097d4471cdcec108b9       -  test-data} !~ qr{(?^:^\s*([0-7]{6}) (tree|blob) ([0-9a-f]+)\s+(-|\d+)\t(.+)\x00)} at INST/lib/perl5/App/Git/StrongHash/Objects.pm line 228.`
* [ ] Defer subprocess start, else we get so many `[w] DESTROY before close on 'git ...` warnings upon failure that the error message is swamped.
* [ ] `git grep X[X]X` comments from source to here
* [ ] Teach App::Git::StrongHash::Objects to subtract already-hashed objects
* [ ] Notice when A:G:SH:Objects discovers new objects which relate only to the previous signature, and defer
* [ ] Stream digestfiles directly into some other ref namespace
* [ ] Machinery to get these signed by something from time to time
