package App::Git::StrongHash::Piperator;
use strict;
use warnings;

use Carp;

use parent 'App::Git::StrongHash::Iterator';


sub new {
  my ($class, @cmd) = @_;
  my $self =
    { cmd => [ @cmd ],
      caller => [ caller(0) ] };
  bless $self, $class;
  $self->irs($/);
  return $self->_start;
}

sub irs {
  my ($self, @set) = @_;
  ($self->{irs}) = @set if @set;
  return $self->{irs};
}

sub _caller {
  my ($self) = @_;
  my $c = $self->{caller};
  return "$c[1]:$c[2]";
}

sub _start {
  my ($self) = @_;
  my @cmd = @{ $self->{cmd} };
  my $pid = open my $fh, '-|', @cmd or $self->fail("fork failed: $!");
  @{$self}{qw{ pid fh }} = ($pid, $fh);
  return $self;
}

sub fail {
  my ($self, $msg) = @_;
  my @cmd = @{ $self->{cmd} };
  die "$msg in @cmd";
}

sub DESTROY {
  my ($self) = @_;
  return unless exists $self->{fh}; # blessed but _start failed
  my @cmd = @{ $self->{cmd} };
  my $caller = $self->_caller;
  warn "[w] DESTROY before close on @cmd from $caller" if defined $self->{fh};
  return;
}

sub finish {
  my ($self) = @_;
  my $fh = $self->{fh};
  $self->{fh} = undef;
  $self->fail("double finish") unless defined $fh;
  if (!close $fh) {
    my $err = $? == -1 ? $! : $?;
    $self->fail("command failed $err");
  }
  return $self;
}

sub nxt {
  my ($self) = @_;
  croak "wantarray!" unless wantarray;
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
