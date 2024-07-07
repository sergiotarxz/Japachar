#!/usr/bin/env perl

use v5.38.2;

use strict;
use warnings;

use Test::Most tests => 3;
use Test::MockModule;
use Test::MockObject;
use Path::Tiny;

use File::Basename;

use lib dirname( dirname(__FILE__) ) . '/lib';

use JapaChar;

BEGIN {
    use_ok 'JapaChar::View::HiraganaKatakanaLesson';
}

my $home = Path::Tiny->tempdir;
$ENV{HOME} = $home;

{
    my $app    = JapaChar->new;
    my $lesson = JapaChar::View::HiraganaKatakanaLesson->new( app => $app );
    my $called_on_exit = 0;
    my $id = 'exit-the-lesson';
    my $mock_main_menu = Test::MockObject->new;
    $mock_main_menu->mock(run => sub {
    });
    my $mock_module_main_menu = Test::MockModule->new('JapaChar::View::MainMenu');
    my $received_app;
    $mock_module_main_menu->mock('new' => sub($self, %args) {
        $received_app = $args{app};
        return $mock_main_menu;
    });
    $lesson->_on_dialog_exit_lesson_response(
        $id,
        sub {
            $called_on_exit = 1;
        }
    );
    ok $called_on_exit, 'On exit dialog cleanup';
    ok $received_app->can('window_set_child'), 'On exit main menu is called with a valid app as parameter';
}
