package App::Git::StrongHash::CatFilerator;
use strict;
use warnings;

use POSIX ();
use Carp;
use Try::Tiny;
use File::Temp 'tempfile';

use parent 'App::Git::StrongHash::Piperator';


=head1 NAME

App::Git::StrongHash::CatFilerator - "git cat-file" into an ObjHasher

=head1 DESCRIPTION

A specialise L<App::Git::StrongHash::Piperator> for use between
L<App::Git::StrongHash::Objects> and
L<App::Git::StrongHash::ObjHasher>.


=head1 CLASS METHOD

=head2 new($repo, $hasher, $objid_iterator)

Define the command and start it.

The iterator B<might not> be consumed in this thread - implementation
may change.

=cut

sub new {
  my ($class, $repo, $hasher, $objids, $output_method) = @_;
  my @cmd = ($repo->_git, qw( cat-file --batch ));
  my $self =
    { repo => $repo,
      hasher => $hasher,
      objids => $objids, # is consumed in _ids_dump
      output_method => $output_method,
      # objids_fn => filename of tmpfile once made, then undef when unlinked
      chunk => 128*1024, # bytes of object per bite
      cmd => \@cmd,
      caller => [ caller(0) ] };
  bless $self, $class;
  return $self;
}

sub _ids_dump {
  my ($self) = @_;
  my $iter_in = delete $self->{objids}
    or confess "read objids: too late";
  my ($fh, $filename) = tempfile('objids.txt.XXXXXX', TMPDIR => 1);
  local $\ = "\n"; # ORS
  while (my ($nxt) = $iter_in->nxt) {
    print {$fh} $nxt or die "printing to $filename: $!";
  }
  close $fh or die "closing $filename: $!";
  $self->{objids_fn} = $filename;
  return $filename;
}

# this interface to the filename enforces write-once-read-then-unlink
sub _ids_fn {
  my ($self) = @_;
  return $self->_ids_dump unless exists $self->{objids_fn};
  return $self->{objids_fn}; # undef after _cleanup unlinks
}

sub _cleanup {
  my ($self) = @_;
  my $fn = $self->{objids_fn}; # not _ids_fn, don't create-just-to-unlink
  unlink $fn if defined $fn; # on error...  well we left some cruft
  undef $self->{objids_fn};
  return;
}

sub start {
  my ($self) = @_;
  my $objlist = $self->_ids_fn;
  confess "read objids_fn: too late" unless defined $objlist;

  my $pid = open my $fh, '-|';
  if (!defined $pid) {
    $self->fail("fork failed: $!");
  } elsif ($pid) {
    # parent
    binmode $fh;
    @{$self}{qw{ pid fh }} = ($pid, $fh);
    return $self;
  } else {
    $self->_child($objlist, @{ $self->{cmd} });
    # no return
  }
}

sub _child {
  my ($self, $fn, @cmd) = @_;
  unless (open STDIN, '<', $fn) {
    @cmd = qw( false );
    warn "open $fn for reading: $!";
  }
  exec @cmd;
  warn "exec '@cmd' failed: $!";
  POSIX::_exit(1);
}


=head2 finish()

Clean up the tmpfile, then close the pipe filehandle as for
L<App::Git::StrongHash::Piperator/finish>.

=cut

sub finish {
  my ($self) = @_;
  $self->_cleanup;
  return $self->SUPER::finish;
}

=head2 nxt()

In list context, fetch one Git object from the parent C<nxt> and feed
it, in chunks if necessary, to the ObjHasher.

When the objectid comes back missing, C<warn> and continue with the
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
  my ($objid, $type, $size) = $line =~ m{^(\S+) (\S+)(?: (\d+))?$} or
    $self->fail("cat-file parse fail on '\Q$line\E'");

  if ($type eq 'missing') {
    warn "Expected objectid $objid, it is missing\n";
    return $self->nxt;
  }

  # Object contents follow
  $hasher->newfile($type, $size, $objid);
  my $blk;
  my $bytes_left = $size;
  $self->irs(\$chunk);
  while ($bytes_left > 0) {
    $chunk = $bytes_left if $bytes_left < $chunk;
    ($blk) = $self->SUPER::nxt;
    $self->fail("EOF with $bytes_left/$size to go of $objid") if !defined $blk;
    $hasher->add($blk);
    $bytes_left -= length($blk);
  }

  # Trailing LF
  $self->irs("\n");
  ($blk) = $self->SUPER::nxt;
  $blk = '[eof]' unless defined $blk;
  $self->fail("object $objid unterminated ($blk)") unless $blk eq "\n";

  # Return value
  return scalar $hasher->$output_method;
}


1;
