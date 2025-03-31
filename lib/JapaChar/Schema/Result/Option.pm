package JapaChar::Schema::Result::Option;

use v5.38.2;

use strict;
use warnings;

use feature 'signatures';

use parent 'DBIx::Class::Core';

use Encode qw/decode/;

sub FAIL_PENALTY_BASIC_CHARACTER {
    return 'fail_penalty_basic_character';
}

sub SUCCESS_REWARD_BASIC_CHARACTER {
    return 'success_reward_basic_character';
}

sub get_success_reward_basic_character {
    my ($result) = JapaChar::Schema->Schema->resultset('Option')->search({ name => SUCCESS_REWARD_BASIC_CHARACTER() });
    if (!defined $result || !defined $result->value) {
        return 5;
    }

    if ($result->value < 1) {
        return 1;
    }

    if ($result->value > 30) {
        return 30;
    }

    return $result->value;
}

sub CONSECUTIVE_SUCCESS_REWARD_BASIC_CHARACTER {
    return 'consecutive_success_reward_basic_character';
}

sub get_consecutive_success_reward_basic_character {
    my ($result) = JapaChar::Schema->Schema->resultset('Option')->search({ name => CONSECUTIVE_SUCCESS_REWARD_BASIC_CHARACTER() });
    if (!defined $result || !defined $result->value) {
        return 10;
    }

    if ($result->value < 0) {
        return 0;
    }

    if ($result->value > 20) {
        return 20;
    }

    return $result->value;
    
}

sub MAX_NUMBER_SIMULTANEOUS_LEARNING_BASIC_CHARACTERS {
    return 'max_number_simultaneous_learning_basic_characters';
}

sub get_max_number_simultaneous_learning_basic_characters {
    my ($result) = JapaChar::Schema->Schema->resultset('Option')->search({ name => MAX_NUMBER_SIMULTANEOUS_LEARNING_BASIC_CHARACTERS() });
    if (!defined $result || !defined $result->value) {
        return 5;
    }

    if ($result->value < 1) {
        return 1;
    }

    if ($result->value > 20) {
        return 20;
    }

    return $result->value;
    
}
sub NEW_CHARACTER_THREESHOLD_BASIC_CHARACTER_INNER_SCORE {
    return 'new_character_threeshold_basic_character_inner_score';
}

sub get_new_character_threeshold_basic_character_inner_score {
    my ($result) = JapaChar::Schema->Schema->resultset('Option')->search({ name => NEW_CHARACTER_THREESHOLD_BASIC_CHARACTER_INNER_SCORE() });
    if (!defined $result || !defined $result->value) {
        return 100;
    }

    if ($result->value > get_max_inner_score_basic_char()) {
        return get_max_inner_score_basic_char();
    }

    return $result->value;
    
}

sub MAX_INNER_SCORE_BASIC_CHAR {
    return 'max_inner_score_char';
}

sub get_max_inner_score_basic_char {
    my ($result) = JapaChar::Schema->Schema->resultset('Option')->search({ name => MAX_INNER_SCORE_BASIC_CHAR() });
    if (!defined $result || !defined $result->value) {
        return 130;
    }

    if ($result->value > 1000) {
        return 1000;
    }

    if ($result->value < 130) {
        return 130;
    }

    return $result->value;
}

sub REVIEW_INSTEAD_OF_LEARNING_CHANCE_BASIC {
    return 'review_instead_of_learning_chance_basic';
}

sub get_review_instead_of_learning_chance_basic {
    my ($result) = JapaChar::Schema->Schema->resultset('Option')->search({ name => REVIEW_INSTEAD_OF_LEARNING_CHANCE_BASIC() });
    if (!defined $result || !defined $result->value) {
        return 20;
    }
    if ($result->value > 90) {
        return 90;
    }

    if ($result->value < 10) {
        return 10;
    }
    return $result->value;
}

__PACKAGE__->table('options');

__PACKAGE__->add_columns(
    name => {
        data_type   => 'TEXT',
        is_nullable => 0,
    },
    value => {
        data_type   => 'TEXT',
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key('name');
1;
