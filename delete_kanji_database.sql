delete from kanji;
delete from kanji_on_readings;
delete from kanji_kun_readings;
delete from kanji_meanings;
update options set value = 0 where name = 'kanji_version';
