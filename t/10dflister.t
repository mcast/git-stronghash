#!perl
use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Differences;

use App::StrongHash::DfLister;

use lib 't/lib';
use Local::TestUtil qw( testdigestfile tryerr );


sub main {
  plan tests => 9;
  unified_diff;

  my $dfl_self = App::StrongHash::DfLister->new
    ('self-0.01' => testdigestfile('self-0.01'));
  my $dfl_notag = App::StrongHash::DfLister->new
    (untagged => testdigestfile('test-data-no-tags-b105de8d622dab99968653e591d717bc9d753eaf'));

  my @self_newci = self_newci();
  my %newci_idx;

  is(rangify(qw( 5 6 7 8 10 11 12 14 17 18 )),
     '5..8, 10..12, 14..14, 17..18', 'check rangify');

  @newci_idx{@self_newci} = (0 .. $#self_newci);
  my $old = $dfl_self->whittle(\%newci_idx, 0);
  is($old, \%newci_idx, "whittle: hashref returned");
  is(rangify(values %newci_idx),
     '41..88', # 41 == 0.01, 88 = iec
     'whittle: get old ones');

  like(tryerr { $dfl_self->whittle({}) },
       qr{^ERR:Set \$exist true to keep unseens, },
       'whittle: need bool');

  my $new = {};
  @{$new}{@self_newci} = (0 .. $#self_newci);
  $dfl_self->whittle($new, 1);
  is(rangify(values %$new),
     '0..40', # 0 == recentHEAD, 40 == 0.01-1-geb247b3
     'whittle: get new ones');
#  note explain { old => $old, new => $new };

  my $cmd = "git rev-list --objects $self_newci[41] 0.01 ";
  my @old_objs = qx{$cmd};
  foreach (@old_objs) { chomp; s/ .*// }

  my @lost = qw(
    0652ec3fc9561a6d22a6c63904b9ca368325f882
    10862fbdc55b3f80ed8b8fd879a2034279fdf04f
    12edea27f52d702311b4e9bf207a9e1e3d4d967e
    21bf610de1a2a16369628a7cdfef138d060363a1
    22234def5f994cd07b7e8f8971cd4ac81e7be168
    3052e3519e9890f645d77c33fd1e884edd40e0f8
    e83515ed8991a1bf916f80fe7e5ff37e4cb256cf
	      ); # signed with 0.01 but I don't have them any more
  eq_or_diff((join "\n", sort @{ $dfl_self->all }),
	     (join "\n", sort @old_objs, @lost),
	     'all')
    or note "expected are from   $cmd | cut -d' ' -f1";

  # find, list context
  is_deeply([ $dfl_self->find(@self_newci[39 .. 45]) ],
	    [qw[ 0 0 1 1 1 1 1 ]], 'find(39..45)');

  # find, scalar context
  is($dfl_self->find('e83515ed8991a1bf916f80fe7e5ff37e4cb256cf'), 1, 'find: true');
  is($dfl_self->find('hedgehogs'), 0, 'find: false');

  return 0;
}


exit main();


sub self_newci {
  return grep {/^[0-9a-f]{40}/} qw(
287c193ecaccfa26b0424a77025ea6326a3207d6 recentHEAD
013d76209da0841ab8c3afe905a0f2b27000ee93
225b879b73963e62647d15cf93d807421cc422e7
55fb8a5b4a05b84485546a53ed3bea44ddfd6e67
7c5541628f50c9f3591bdc0211574f89ae2a161e
1a4e084fc02b303eaeb617dc1ee4f660249a276b
9754552d0a53cb367d3d66aa35d76bce1008c7db
30aed6bcdaf08796467767ca4892f85667378d14
10af54aced4d65a571e3f7c9040500c9ef294983
78983a881aa7be0a8c8ad7b0597dddb1a9e9112a
2f4792221ee5d1d2d88db043619b0301bc5e2691
2457cb3c320b8b1108b5e83ea8df019108fca207
d663cc8eb6e47b0546618e671298af6dd8272089
e995698f783d5a5386123434cfe6d097dcb0f979
d1fe249460ef099864101f4af3187387d06d45d8
62e06b095075f7ebf11c862b7b31344892bd3d49
e5bbe6817b40286cea2f20e8e8f78d53387e4843
0a07429fbdb00338c42974d9deb42c8ff9786121
2cea262dcdb5e391893f42108c5bda9243b73afc
8e87e51525e1ee4886c810866b3e8b33501395fd
11bdeea13af1b9c0b040952a85747fdbbf0fe4f0
c572f7035a886a6931d8c032d7d2cf7221e77672
106e2a7fd889edee12e894f58935b1f44361d483
7380b52d8a9f7f7d4a8ae7130e47454231136021
84c4ca4901ed45ced124000614ed4f0ae11f2306
e4e8261c1251f7966a65cd66238b1b5f85aa1d4f
ce53b5915f2d5dc7a67a47f0cee79a00232c702d
5aeef4793504380c3ed1344b9e8f554db97fde95
471fa4a4a45cb640310a373c2cf1ffbe14b914e6
e44bd58c2751b4e5ba7a1057ed23a6e5a7f4bfb2
29d3440ec54c2739a2569fd45c549cf67b8d1b17
fdd6f09f989024793c99f8761b67be41a8cb89fe
2b8ec4ef57ff92bbcb0c47e2d03bc384c681d057
dd6d68dec21e0e2dfc09d621c4d20fd478f51a45
c4935f5d39d84a060d4540023b6a68ccccff6782
cae83627fca879b696d55570cf0be62c7263e19a
d228dba93b9935c1fcd587a9155cd41a9e12e13e
85e8cc17e8f7fa658cebdb595c265036ef7225ab
d72f17481aed5c4c692810e50489bd604b060c93
de6c8db6d43bcedd2ac344f10377aeff4dd90275
eb247b3a6d3e37ef9bc4f68bd57045761c1ae4be
8d270d7eda8b7409b4e1566deadc28dece8bf412  0.01
bf71c4b969cee0e7111089948faddb2be90bf530
4dff2fa41b24b1ffaece27d36fb597f1132a9c0b
5b4941948c5755cb0b8d993c63bf4e388da6b3a0
be6a3a63bb7c629dc9105f3a507b5deb9d15eb64
cd6e81354f3cc8504e0c59b3d61c508b7bc54465
5bb7c40ca19d0e7d3f86cb4df868e17710b86fc7
5c6468d20a6edc76ae0052a90f574b6040a3a543
4ff18e42a16dd798119dfbd8e3e334ba58646d30
ee3b814228bd3aeb71cbe2991f8fd859d4d53dc2
aea376b3e845e642f1fb28bc9b1270696e6bab3c
1f842b4f3ad098486003800aa6490558463e846b
f5156b78efcdae883dd401f7ec2e7c1cb6c87b1b
c5d1960c4d34b6d1b130a9ecd55b83bc6aacb565
b8f45bbddbdea225b734fd63a0054c07d298a02a
8b447c84d9bcb11cd31b14c2e2e106ae34170fa0
f7fb63dc33907d17752833707accbe1e031ff99e
a9872f7946836c030adb35bf4a92cb703de9e485
cd2ac2baa9740170b4c896466311e1f6908c3cda
ae2122e81a8dba0f8ccdc0dc6115b97a52de029d
430fe07727f535121f83f094ec7ab55770b69a25
c6190baec6557abbf83dd4ecbb8990fbcb669eee
e08c33b3c1f9435790e4001c3d6a2f3dc5702aa3
68893fe9bee7f57918503ec05b85278afef25219
ee4aff8e5679fe05d9018119759cf4e747a00111
e039bfde0a45e6714f9cab2f849b64bc4350adc1
e923799b83bfcedcf49026a9a4bbad60bc56f4b9
e500543309af5d334fc1c839583de04923e1d70c
cb868f531996abb3255d8b2a7ccbcb20ceec3e57
4c2c1f9ded7e4cd46ca6526b093bf767890fa845
2697295389f22eed9025d19f3a0e6ea53d008610
2637fe858ac6aa6b32e0c751cea1d8d0e10aadc9
b19e35ea60bf8d0fa3c633f5c82e260283a1f2e7
7aaa7f85a23345909d83179dfe0a0a37885f4efa
7bfdc12fb33071179dd925e156a07e5fb6e644dc
3ac6c85cd32aaff50b161efa66608f17f3f329af
9d3ecedbe69ad4ca0f881f8b7a2f90081f09d48e
2e3226a08ab248374267d1a6ef848bd5263a07da
1c33563543ada05e3b732b27fe432f203da8b052
9c649489eee4bfba4b9b86374a7cbd4eabe8bb2e
adfc4b6fe3fd99e0019d1fe358aef29f770816dd
199556da40c54cd20afa895efa8ed0e9c3164962
315026a76bd00d1fe42b875027d43c1e3285babb
1e7167086133e3a5babd48d2aaa6a992bf2bf2ab
0adcbd82e786df998f7a59ec9238667e4e5b1e68
380555dbd33ffa159273e37dc3a170b98dd61c7d
9864be52e147ae6ae4b59e71ae1f03018c96bf3f
d4e360cf2e2fc26cc1b0f7e42e00195b4e159b82 iec
    );
}


sub rangify {
  my @n = @_;
  my ($l, $r, @r);
  my $put = sub { push @r, "$l..$r" if defined $l; undef $l };
  for my $n (sort { $a <=> $b } @n) {
    if (defined $l && $r + 1 == $n) {
      $r = $n;
    } else {
      $put->();
      $l = $r = $n;
    }
  }
  $put->();
  local $" = ', ';
  return wantarray ? @r : "@r";
}
