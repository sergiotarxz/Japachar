package JapaChar::Random;

use v5.38.2;

use strict;
use warnings;

use Moo;

use Crypt::URandom qw( urandom );

sub get($class, $min = 1, $max = 100) {
    my $rng = urandom(4);
    $rng = unpack 'L', $rng;
    say $rng;
    $rng = ($rng % $max) + $min;
    return $rng;
}
1;
