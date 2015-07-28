package App::Git::StrongHash::Piperator;
use strict;
use warnings;

use Carp;
use Try::Tiny;

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
  return $self->_start;
}

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

sub _start {
  my ($self) = @_;
  my @cmd = @{ $self->{cmd} };
  my ($pid, $fh);
  try {
    $pid = open $fh, '-|', @cmd;
  } catch {
    $self->fail("fork died: $_");
  };
  $self->fail("fork failed: $!") unless $pid;
  @{$self}{qw{ pid fh }} = ($pid, $fh);
  return $self;
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
  return unless exists $self->{fh}; # blessed but _start failed
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
  my $fh = $self->{fh};
  $self->fail("not running") unless $fh;
  local $/ = $self->irs;
  my $ln = <$fh>;
  if (defined $ln) {
    return ($ln);
  } else {
    $self->finish;
    return ();
  }
}


1;
