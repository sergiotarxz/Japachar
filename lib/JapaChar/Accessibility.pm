package JapaChar::Accessibility;

use v5.38.2;

use strict;
use warnings;

use Moo;

require JapaChar::Schema;

my $option_name = 'accessibility-mode';
my $dyslexia = 'dyslexia';
my $remove_assisted_mode = 'remove-assisted-mode';

has app => (is => 'ro');

sub _current_mode($self) {
    my ($result) = JapaChar::Schema->Schema->resultset('Option')->search({ name => $option_name });
    my $return = '';
    if (defined $result) {
        $return = $result->value;
    }
    return $return;
}

sub is_dyslexia($self) {
    return $self->_current_mode eq $dyslexia;
}

sub show_assisted_mode_selection($self) {
    my $dialog = Adw::AlertDialog->new( 'Select assisted mode',
        'If you feel you are not progressing as well as you could try one of these, do not take one of them working for you as a diagnosis.' );
    $dialog->add_response( $dyslexia, 'Dyslexia' );
    $dialog->add_response( $remove_assisted_mode, 'Remove accessibility' );
    $dialog->signal_connect(
        'response',
        sub( $obj, $response ) {
            $self->_on_assisted_mode_selection_response( $response );
        }
    );
    $self->app->present_dialog($dialog);
    return $dialog;
}

sub _on_assisted_mode_selection_response( $self, $response ) {
    if (!defined $response) {
        die 'Accessibility mode invalid';
    }
    my ($result) = JapaChar::Schema->Schema->resultset('Option')->update_or_create({ name => $option_name, value => $response });
}
1;
