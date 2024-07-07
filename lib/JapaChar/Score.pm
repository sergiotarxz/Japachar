package JapaChar::Score;

use v5.38.2;

use strict;
use warnings;

use Moo;

my $option_name = 'user_score';

require JapaChar::DB;
require JapaChar::Schema;

sub _get_row($self) {
    my ($result) = JapaChar::Schema->Schema->resultset('Option')->search({ name => $option_name });
    return $result;
}

sub get($self) {
    return 0 + $self->_get_row->value;
}

sub update($self, $new_value) {
    return $self->_get_row->update({value => $new_value});
}

sub sum($self, $to_sum) {
    if ($to_sum < 0) {
        die "\$to_sum is negative: $to_sum";
    }
    return $self->update($self->get+$to_sum);
}
1;
