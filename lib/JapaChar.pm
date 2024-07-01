package JapaChar;

use v5.38.2;

use strict;
use warnings;

use feature 'signatures';

use Moo;
use Path::Tiny;
use Glib::Object::Introspection;
use YAML::PP;
use JapaChar::DB;
use JapaChar::Characters;
use Pango;
use JapaChar::Random;

use Glib::IO;

use constant PANGO_SCALE => 1024;

Glib::Object::Introspection->setup(
    basename => 'Gtk',
    version => '4.0',
    package => 'Gtk',
);

Glib::Object::Introspection->setup(
    basename => 'Gdk',
    version => '4.0',
    package => 'Gtk::Gdk',
);

Glib::Object::Introspection->setup(
    basename => 'Gsk',
    version => '4.0',
    package => 'Gtk::Gsk',
);

Glib::Object::Introspection->setup(
    basename => 'Adw',
    version => '1',
    package => 'Adw',
);


has _counter => (
    is => 'rw',
);

has _headerbar => (
    is => 'rw',
);

sub config($class) {
    my $ypp = YAML::PP->new;
    $ypp->load_file(''.path(__FILE__)->parent->parent->child('config.yml'));
}

sub _start_lesson($self, $window, $type = undef) {
    $self->_counter(11);
    $self->_new_challenge($window, $type);
}

sub _new_challenge($self, $window, $type = undef) {
    $self->_counter($self->_counter - 1);
    if ($self->_counter < 1) {
        $self->_create_main_menu($window);
        return;
    }
    my $rng = JapaChar::Random->new->get(1, 100);
    if ($rng > 50) {
        $self->_new_challenge_romanji($window, $type);
        return;
    }
    $self->_new_challenge_kana($window, $type);
}

sub _new_challenge_romanji($self, $window, $type = undef) {
    my $show = 'romanji';
    my $guess = 'kana';
    $self->_new_challenge_generic_code($window, $type, $show, $guess);
}

sub _new_challenge_generic_code($self, $window, $type, $show, $guess) {
    my $grid = $self->_create_grid_challenge;
    my $char = JapaChar::Characters->new->next_char($type);
    my $kana_label = $self->_get_label_featured_character($char->get($show));
    $kana_label->set_halign('center');
    $kana_label->set_valign('center');
    $grid->attach($kana_label, 0, 0, 12, 1);
    $self->_window_set_child($window, $grid);
    my $back_button = Gtk::Button->new_from_icon_name('go-previous-symbolic');
    $back_button->signal_connect('clicked', sub {
        my $dialog = Adw::Dialog->new;
        $dialog->set_content_width(460);
        $dialog->set_content_height(400);
        my $main_box = Gtk::Box->new('vertical', 0);
        $main_box->set_vexpand(1);
        my $grid = Gtk::Grid->new;
        my $headerbar = Adw::HeaderBar->new;
        $main_box->append($headerbar);
        my $label = Gtk::Label->new('You are about to exit the lesson');
        $main_box->append($label);
        $label->set_property('height_request', 250);
        $label->set_valign('center');
        $label->set_halign('center');
        my $attr_list = Pango::AttrList->new;
        my $size = Pango::AttrSize->new(18 * PANGO_SCALE);
        $attr_list->insert($size);
        $label->set_attributes($attr_list);
        my $button_box = Gtk::Box->new('horizontal', 15);
        $button_box->set_halign('center');
        $button_box->set_property('height_request', 50);
        $button_box->set_valign('end');
        my $button_accept = Gtk::Button->new_with_label('Lose all progress');
        my $button_reject = Gtk::Button->new_with_label('Continue the lesson');
        $button_accept->signal_connect('clicked', sub {
            $dialog->close;
            $self->_create_main_menu($window);
        });
        $button_reject->signal_connect('clicked', sub {
            $dialog->close;
        });
        $button_accept->set_valign('end');
        $button_reject->set_valign('end');
        $button_accept->add_css_class('destructive-action');
        $button_reject->add_css_class('suggested-action');
        $main_box->append($button_box);
        $button_box->append($button_accept);
        $button_box->append($button_reject);
        $dialog->set_child($main_box);
        $dialog->present($window);
    });
    $self->_headerbar->pack_start($back_button);
    my $incorrect_chars = JapaChar::Characters->new->get_4_incorrect_answers($char);
    my @buttons;
    my $continue_button = Gtk::Button->new_with_label('Continue');
    $continue_button->set_valign('center');
    $continue_button->set_halign('end');
    $continue_button->set_sensitive(0);
    $continue_button->add_css_class('accent');
    my $on_answer = sub {
        $continue_button->set_sensitive(1);
    };
    my $correct_answer_button = Gtk::ToggleButton->new_with_label($char->get($guess));
    my $final_answer;
    $correct_answer_button->signal_connect('clicked', sub {
        $final_answer = $char->get($guess);
        $on_answer->();
    });
    push @buttons, $correct_answer_button;
    for my $char (@$incorrect_chars) {
        my $incorrect_button = Gtk::ToggleButton->new_with_label($char->get($guess));
        $incorrect_button->set_group($correct_answer_button);
        $incorrect_button->signal_connect('clicked', sub {
            $final_answer = $char->get($guess);
            $on_answer->();
        });
        push @buttons, $incorrect_button;
    }
    @buttons = sort { rand() <=> rand() } @buttons;
    my $box = Gtk::Box->new('horizontal', 10);
    $box->set_valign('center');
    $box->set_halign('center');
    for my $button (@buttons) {
       my $attr_list = Pango::AttrList->new;
       my $size = Pango::AttrSize->new(42 * PANGO_SCALE);
       $attr_list->insert($size);
       $button->get_child->set_attributes($attr_list);
       $box->append($button);
    }
    my $first_press_continue = 1;
    $continue_button->signal_connect('clicked', sub {
        if (!$first_press_continue) {
            $self->_new_challenge($window, $type); 
            return;
        }
        $first_press_continue = 0;
        my $label_feedback;
        {
            if ($final_answer eq $char->get($guess)) {
                $label_feedback = Gtk::Label->new('You are doing it great.');
                $label_feedback->add_css_class('success');
                $char->success;
                next;
            }
            $label_feedback = Gtk::Label->new('Meck!! The correct answer is ' . $char->get($guess));
            $label_feedback->add_css_class('error');
            $char->fail;
        }
        my $attr_list = Pango::AttrList->new;
        my $size = Pango::AttrSize->new(18 * PANGO_SCALE);
        $attr_list->insert($size);
        $label_feedback->set_attributes($attr_list);
        $grid->attach($label_feedback, 0, 2, 7, 1);
    });
    $grid->attach($box, 0, 1, 12, 1);
    my $attr_list = Pango::AttrList->new;
    my $size = Pango::AttrSize->new(25 * PANGO_SCALE);
    $attr_list->insert($size);
    $continue_button->get_child->set_attributes($attr_list);
    $grid->attach($continue_button, 6, 2, 5, 1);
}

sub _new_challenge_kana($self, $window, $type = undef) {
    my $show = 'kana';
    my $guess = 'romanji';
    $self->_new_challenge_generic_code($window, $type, $show, $guess);
}

sub _create_grid_challenge($self) {
    my $grid = Gtk::Grid->new;
    $grid->set_column_homogeneous(1);
    $grid->set_row_homogeneous(1);
    return $grid;
}

sub _get_label_featured_character($self, $text) {
    my $label = Gtk::Label->new($text);
    my $attr_list = Pango::AttrList->new;
    my $size = Pango::AttrSize->new(72 * PANGO_SCALE);
    $attr_list->insert($size);
    $label->set_attributes($attr_list);
    $label->set_halign('center');
    return $label;
}

sub _create_main_menu($self, $window) {
    my $grid = Gtk::Grid->new;
    my $button_start_basic_lesson = Gtk::Button->new_with_label('Basic Characters');
    $button_start_basic_lesson->signal_connect('clicked', sub {
        $self->_start_lesson($window);
    });
    $grid->set_column_homogeneous(1);
    $grid->set_row_homogeneous(1);
    my $button_start_hiragana_lesson = Gtk::Button->new_with_label('Hiragana');
    $button_start_hiragana_lesson->signal_connect('clicked', sub {
        $self->_start_lesson($window, 'hiragana');
    });
    my $button_start_katakana_lesson = Gtk::Button->new_with_label('Katakana');
    $button_start_katakana_lesson->signal_connect('clicked', sub {
        $self->_start_lesson($window, 'katakana');
    });
    for my $button ($button_start_basic_lesson, $button_start_hiragana_lesson, $button_start_katakana_lesson) {
       my $attr_list = Pango::AttrList->new;
       my $size = Pango::AttrSize->new(25 * PANGO_SCALE);
       $attr_list->insert($size);
       $button->get_child->set_attributes($attr_list);
    }
    my $box = Gtk::Box->new('horizontal', 10);
    $grid->attach($button_start_basic_lesson, 0, 0, 5, 1);
    $button_start_basic_lesson->set_valign('end');
    $button_start_basic_lesson->set_halign('center');
    $box->set_margin_top(40);
    $box->append($button_start_hiragana_lesson);
    $box->append($button_start_katakana_lesson);
    $box->set_valign('start');
    $box->set_halign('center');
    $grid->attach($box, 0, 1, 5, 1);
    $self->_window_set_child($window, $grid);
}

sub _window_set_child($self, $window, $child) {
    my $box = Gtk::Box->new('vertical', 0);
    my $headerbar = Adw::HeaderBar->new;
    $headerbar->set_title_widget(Gtk::Label->new('Japachar'));
    $box->append($headerbar);
    $box->append($child);
    $child->set_vexpand(1);
    $window->set_content($box);
    $self->_headerbar($headerbar);
}

sub _application_start($self, $app) {
    my $main_window = Adw::ApplicationWindow->new($app);
    $main_window->set_default_size(600, 600);
    my $display = $main_window->get_property('display');
    my $css_provider = Gtk::CssProvider->new;
    $css_provider->load_from_path(path(__FILE__)->parent->parent->child('styles.css')->absolute);
    Gtk::StyleContext::add_provider_for_display($display, $css_provider, 'priority-fallback');
    $self->_create_main_menu($main_window);
    $main_window->present;
}

sub start($self) {
    my $app = Adw::Application->new('me.sergiotarxz.JapaChar', 'default-flags'); 
    $app->signal_connect('activate' => sub {
        $self->_application_start($app);
    });
    $app->run;
}
1;
