use v6;

use Test;
use Test::When <extended>;

use DB::Pg;

plan 5;

my $pg = DB::Pg.new;

lives-ok { $pg.execute('drop table if exists test') }, 'drop table test';

lives-ok { $pg.execute(q:to//) }, 'create table test';
    create table test
    (
        x int,
        y text
    )

$pg.db.execute('copy test from stdin (format csv)')
      .copy-data(q:to//).copy-end.finish;
    1,"something"
    2,"more stuff"
    3,"yet more"
    4,"how about this"

is $pg.query('select y from test where x = $1', 2).value, 'more stuff',
    'copy in';

is-deeply $pg.execute('copy test to stdout (format csv)'),
    ( "1,something\n", "2,more stuff\n", "3,yet more\n", "4,how about this\n"),
    'copy out';

lives-ok { $pg.execute('drop table if exists test') }, 'drop table test';

done-testing;
