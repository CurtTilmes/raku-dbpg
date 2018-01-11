use Test;
use Test::When <extended>;

use DB::Pg;

plan 12;

my $pg = DB::Pg.new;

lives-ok { $pg.execute(q:to//) }, 'create table test';
    create table test
    (
        x int,
        y text
    )

my $db = $pg.db;

lives-ok { $db.begin }, 'begin';

lives-ok { $db.query('insert into test values ($1, $2)', 1, 'this') }, 'insert';

is-deeply $db.query("select * from test").hashes,
          ({ x => 1, y => 'this' },), 'select';

lives-ok { $db.rollback }, 'rollback';

is-deeply $db.query("select * from test").hashes,
          (), 'select empty';

lives-ok { $db.begin }, 'begin';

lives-ok { $db.query('insert into test values ($1, $2)', 1, 'this') }, 'insert';

is-deeply $db.query("select * from test").hashes,
          ({ x => 1, y => 'this' },), 'select';

lives-ok { $db.commit }, 'commit';

is-deeply $db.query("select * from test").hashes,
          ({ x => 1, y => 'this' },), 'select';

$db.finish;

lives-ok { $pg.execute('drop table test') }, 'drop table test';

done-testing;
