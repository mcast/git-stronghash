package App::StrongHash::Regexperator;
use strict;
use warnings;

use Carp;

use parent 'App::StrongHash::Iterator';


=head1 NAME

App::StrongHash::Regexperator - regexp mapping iterator

=head1 DESCRIPTION

Given an iterator and regexp, apply the regexp to each item on the
input and return the captures.  Dies on regexp failure.

=head1 CLASS METHOD

=head2 new($iter, $regex, $errmsg)

Create for given L<App::StrongHash::Iterator> and Regexp, with the
first part of the error message for non-match.

$errmsg defaults to "No match".

=cut

sub new {
  my ($class, $iter, $regex, $errmsg) = @_;
  $errmsg = "No match" unless defined $errmsg;
  my $self =
    { iter => $iter,
      regex => $regex,
      errmsg => $errmsg };
  bless $self, $class;
  return $self;
}

=head2 nxt()

In list context, call L<App::StrongHash::Iterator/nxt> and attempt the
match.

=over 4

=item * Return nothing when the input is empty.

=item * Die on match failure.

=item * Return the input if there are no captures.

=item * Return the capture if there is exactly one.

=item * Return a listref of two or more captured substrings.

=back

=cut

sub nxt {
  my ($self) = @_;
  croak "wantarray!" unless wantarray;
  my $n = (my $in) = $self->{iter}->nxt;
  my $re = $self->{regex};
  if ($n) {
    my $m = my @m = $in =~ $re;
    my $errmsg = $self->{errmsg};
    croak "$errmsg: q{$in} !~ qr{$re}" unless $m;
    return $in if 1 == $m && !defined $1 && 1 eq $m[0];
    return $1 if 1 == $m;
    return \@m;
  } else {
    return ();
  }
}

1;
