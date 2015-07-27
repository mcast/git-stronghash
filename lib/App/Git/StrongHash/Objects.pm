package App::Git::StrongHash::Objects;
use strict;
use warnings;

sub add_tags {
  my ($self) = @_;
  my $tags = $self->{tags} ||= {};
  foreach my $ln ($self->pipefrom(qw( git show-ref --tags ))) {
    # 4ef2c9401ce4066a75dbe3e83eea2eace5920c37 refs/tags/fif
    # d9101db5d2c6d87f92605709f2e923cd269affec refs/tags/goldfish
    # 9385c9345d9426f1aba91302dc1f34348a4fec96 refs/tags/goldfish^{}
    my ($tagid, $tagref) = m{^(\w+)\s+(\S+)$} or die "Can't read tagid in $ln";
    $tags->{$tagref} = $tagid;
  }
  return $self;
}

sub add_commits {
  my ($self) = @_;
  my $cis   = $self->{ci} ||= {};
  my $trees = $self->{toptree} ||= {};
  my @maybe_dele = grep { !defined $cis->{$_} } keys %$cis;
  push @maybe_dele, values %{ $self->{tags} ||= {} };
  # git log --all brings all current refs, but may have been given deleted tags+commitids
  foreach my $ln ($self->pipefrom(qw( git log --format=%H,%T --all ), @maybe_dele)) {
    my ($c, $t) = $ln =~ m{^(\w+),(\w+)$}
      or die "Can't read ciid,treeid = $ln";
    $cis->{$c} = $t unless defined $cis->{$c};
    $trees->{$t} = undef unless exists $trees->{$t};
  }
  return $self;
}

sub add_trees {
  my ($self) = @_;
  my $trees = $self->{toptree} ||= {};

#mcra@peeplet:~/gitwk-github/git-stronghash/test-data/d1$ git ls-tree -r -t -l --full-tree -z ae5349e79d17a | perl -pe 's/\x00/\\x00/g'
#040000 tree 5c1e1d7e049f5201eff7c3ca43c405f38564b949       -    d2\x00100644 blob 03c56aa7f2f917ff2c24f88fd1bc52b0bab7aa17      12 d2/shopping.txt\x00100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391       0  mtgg\x00100644 blob f00c965d8307308469e537302baa73048488f162      21        ten\x00mcra@peeplet:~/gitwk-github/git-stronghash/test-data/d1$ 
}

sub pipefrom {
  my ($called, @cmd) = @_;
  return App::Git::StrongHash::Piperator->new(@cmd)->collect;
}

1;
