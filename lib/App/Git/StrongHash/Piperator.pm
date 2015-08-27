package App::Git::StrongHash::Piperator;
use strict;
use warnings;

use Carp;
use Try::Tiny;
use POSIX ();

use parent 'App::Git::StrongHash::Iterator';


=head1 NAME

App::Git::StrongHash::Piperator - iterator reads from command stdout

=head1 DESCRIPTION

Give it a command to run.  Each L</nxt> calls C<< <$fh> >> to return a
line.

=head1 CLASS METHOD

=head2 new(@cmd)

Define the command and start it.

Captures the current C<$/> value for later reading, and remembers the
caller for debug purposes.

=cut

sub new {
  my ($class, @cmd) = @_;
  my $self =
    { cmd => [ @cmd ],
      caller => [ caller(0) ] };
  bless $self, $class;
  $self->irs($/);
  return $self;
}

# TODO: new_later : defer via a Laterator
# TODO: new_parallel : parallelising would be neat, useful for hashing step, maybe as a Forkerator not under Piperator?

=head2 irs

Get/set accessor for the C<local $/> assignment used during reading.

=cut

sub irs {
  my ($self, @set) = @_;
  ($self->{irs}) = @set if @set;
  return $self->{irs};
}

sub _caller {
  my ($self) = @_;
  my $c = $self->{caller};
  return "$$c[1]:$$c[2]";
}

=head2 started()

Return true iff started, including when finished.

=cut

sub started {
  my ($self) = @_;
  return defined $self->{pid};
}

=head2 start()

Run the process and open the pipe from it.  Returns $self in the
parent.

=cut

sub start {
  my ($self) = @_;
  my @cmd = @{ $self->{cmd} };
  my ($pid, $fh);
  try {
    $self->{pid} = 0; # make 'started' true
    $pid = open $fh, '-|', @cmd;
  } catch {
    $self->fail("fork died: $_");
  };
  $self->fail("fork failed: $!") unless $pid;
  @{$self}{qw{ pid fh }} = ($pid, $fh);
  return $self;
}


=head2 start_with_STDIN($fn)

Run the process as in L</start>, but pipe the named file to its STDIN.
Returns $self in the parent.

=cut

sub start_with_STDIN {
  my ($self, $fn) = @_;

  $self->{pid} = 0; # make 'started' true
  my $pid = open my $fh, '-|';
  if (!defined $pid) {
    $self->fail("fork failed: $!");
  } elsif ($pid) {
    # parent
    binmode $fh or croak "binmode pipe from fork: $!";
    @{$self}{qw{ pid fh }} = ($pid, $fh);
    return $self;
  } else {
    $self->_child_stdin($fn, @{ $self->{cmd} });
    # no return
  }
}

sub _child_stdin {
  my ($self, $fn, @cmd) = @_;
  # the uncoverables: I covered them, but Devel::Cover doesn't see it..?
  if (open STDIN, '<', $fn) { # uncoverable branch false
    exec @cmd;
    # perl issues warning on fail
  } else {
    warn "open $fn to STDIN: $!"; # uncoverable statement
  }
  close STDOUT; # uncoverable statement
  close STDERR; # uncoverable statement
  POSIX::_exit(1); # uncoverable statement
}


=head2 fail($msg)

Format a message describing the problem, then C<die> with it.

=cut

sub fail {
  my ($self, $msg) = @_;
  my @cmd = @{ $self->{cmd} };
  die "$msg in '@cmd'\n";
}

=head2 finish()

Close the pipe filehandle and check the return code.  L</fail> if it
is non-zero.

This must be called just once per object.

=over 4

=item * It is normally called automatically at EOF of the pipe.

=item * Calling it again generates a "double finish" error.

=item * Failing to call it before C<DESTROY> happens will generate
warnings.

=back

=cut

sub finish {
  my ($self) = @_;
  croak "Not yet started" unless $self->started;
  my $fh = $self->{fh};
  $self->{fh} = undef;
  $self->fail("double finish") unless defined $fh;
  if (!close $fh) {
    if ($!) {
      $self->fail("command close failed: $!");
    } else {
      my $exit = $? >> 8;
      my $sig = $? & 127;
      $self->fail("command killed by SIG$sig") if $sig;
      $self->fail("command returned $exit");
    }
  }
  return $self;
}

sub DESTROY {
  my ($self) = @_;
  return unless exists $self->{fh}; # blessed but start failed
  my @cmd = @{ $self->{cmd} };
  my $caller = $self->_caller;
  carp "[w] DESTROY before close on '@cmd' from $caller" if defined $self->{fh};
  return;
}

=head2 nxt()

In list context, return one item from the pipe; or nothing at
successful EOF.

=cut

sub nxt {
  my ($self) = @_;
  croak "wantarray!" unless wantarray;
  $self->start unless $self->started;
  my $fh = $self->{fh};
  $self->fail("command has finished") unless $fh;
  my $ln = do { local $/ = $self->irs; <$fh> };
  if (defined $ln) {
    return ($ln);
  } else {
    $self->finish;
    return ();
  }
}


1;
