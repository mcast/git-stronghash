package App::StrongHash::Git::CatFilerator;
use strict;
use warnings;

use Carp;
use Try::Tiny;
use File::Temp 'tempfile';

use parent 'App::StrongHash::Piperator';


=head1 NAME

App::StrongHash::Git::CatFilerator - "git cat-file" into an ObjHasher

=head1 DESCRIPTION

A specialised L<App::StrongHash::Piperator> for use between
L<App::StrongHash::Git::Objects> and L<App::StrongHash::ObjHasher>.


=head1 CLASS METHOD

=head2 new($repo, $hasher, $gitsha1_iterator, $output_method)

Defines a Git command to C<git cat-file> the listed objects, which
will be L</start>ed later.  Object data is sent to $hasher (an
L<App::StrongHash::ObjHasher>) and $output_method is called on it at
the end of each object.

L</nxt> returns the result of each $output_method call.  The
C<output_*> method names are suitable, default is L</output_hex>.

The iterator B<might not> be consumed in this thread - implementation
may change.

=cut

sub new {
  my ($class, $repo, $hasher, $gitsha1s, $output_method) = @_;
  $output_method ||= 'output_hex';
  my @cmd = ($repo->_git, qw( cat-file --batch ));
  my $self =
    { repo => $repo,
      hasher => $hasher,
      gitsha1s => $gitsha1s, # is consumed in _ids_dump
      output_method => $output_method,
      # gitsha1s_fn => filename of tmpfile once made, then undef when unlinked
      chunk => 128*1024, # bytes of object per bite
      cmd => \@cmd,
      caller => [ caller(0) ] };
  bless $self, $class;
  return $self;
}


=head1 OBJECT METHODS

=cut

sub _ids_dump {
  my ($self) = @_;
  my $iter_in = delete $self->{gitsha1s}
    or confess "read gitsha1s: too late";
  my ($fh, $filename) = # _cleanup or _child_stdin should unlink
    tempfile('gitsha1s.txt.XXXXXX', TMPDIR => 1, UNLINK => 1);
  local $\ = "\n"; # ORS
  while (my ($nxt) = $iter_in->nxt) {
    print {$fh} $nxt or die "printing to $filename: $!";
  }
  close $fh or die "closing $filename: $!";
  $self->{gitsha1s_fn} = $filename;
  return $filename;
}

# this interface to the filename enforces write-once-read-then-unlink
sub _ids_fn {
  my ($self) = @_;
  return $self->_ids_dump unless exists $self->{gitsha1s_fn};
  return $self->{gitsha1s_fn}; # undef after _cleanup unlinks
}

sub _cleanup {
  my ($self) = @_;
  my $fn = $self->{gitsha1s_fn}; # not _ids_fn, don't create-just-to-unlink
  unlink $fn if defined $fn; # on error...  well we left some cruft
  undef $self->{gitsha1s_fn};
  return;
}

sub start {
  my ($self) = @_;
  my $objlist = $self->_ids_fn;
  confess "read gitsha1s_fn: too late" unless defined $objlist;
  return $self->start_with_STDIN($objlist);
}


=head2 finish()

Clean up the tmpfile, then close the pipe filehandle as for
L<App::StrongHash::Piperator/finish>.

=cut

sub finish {
  my ($self) = @_;
  $self->_cleanup;
  return $self->SUPER::finish;
}

sub DESTROY {
  my ($self) = @_;
  # TODO: needed because I haven't got the ->finish semantics right, so _cleanup isn't always called
  $self->_cleanup;
  return $self->SUPER::DESTROY;
}

=head2 nxt()

In list context, fetch one Git object from the parent C<nxt> and feed
it, in chunks if necessary, to the ObjHasher.

When the gitsha1 comes back missing, C<warn> and continue with the
next.

Return the output of the chosen ObjHasher method; or nothing at
successful EOF.

=cut

sub nxt {
  my ($self) = @_;
  croak "wantarray!" unless wantarray;
  my $chunk = $self->{chunk};
  my $hasher = $self->{hasher};
  my $output_method = $self->{output_method};

  # emits
  #   <sha1> SP <type> SP <size> LF
  #   <contents> LF
  # or
  #   <object> SP missing LF

  # Object description
  $self->irs("\n");
  my ($line) = $self->SUPER::nxt;
  return () unless defined $line;

  chomp $line;
  my ($gitsha1, $type, $size) = $line =~ m{^(\S+) (\S+)(?: (\d+))?$} or
    $self->fail("cat-file parse fail on '\Q$line\E'");

  if ($type eq 'missing') {
    warn "Expected gitsha1 $gitsha1, it is missing\n";
    return $self->nxt;
  }

  # Object contents follow
  $hasher->newfile($type, $size, $gitsha1);
  my $blk;
  my $bytes_left = $size;
  $self->irs(\$chunk);
  while ($bytes_left > 0) {
    $chunk = $bytes_left if $bytes_left < $chunk;
    ($blk) = $self->SUPER::nxt;
    $self->fail("EOF with $bytes_left/$size to go of $gitsha1") if !defined $blk;
    $hasher->add($blk);
    $bytes_left -= length($blk);
  }

  # Trailing LF
  $self->irs("\n");
  ($blk) = $self->SUPER::nxt;
  $blk = '[eof]' unless defined $blk;
  $self->fail("object $gitsha1 unterminated ($blk)") unless $blk eq "\n";

  # Return value
  return scalar $hasher->$output_method;
}


1;
