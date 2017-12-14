use v6;

use Test;
use Test::When <extended>;

use DB::Pg;

plan 9;

my $pg = DB::Pg.new;

lives-ok { $pg.execute(q:to//) }, 'create table test';
    create table test
    (
        x int,
        y text
    )

my $db = $pg.db;

lives-ok { $db.begin }, 'begin';

ok my $sth = $db.prepare('insert into test values ($1, $2)'), 'prepare';

$sth.execute($_, "line $_ here") for ^10000;

lives-ok { $db.commit }, 'commit';

$db.finish;

is $pg.query('select count(*) from test').value, 10000, '10000 rows inserted';

my @cursor = $pg.cursor('select * from test order by x', :hash);

my $count = 0;
for @cursor -> $row
{
    $count++ if $row eqv %( x => $count, y => "line $count here");
}

is $count, 10000, '10000 rows retrieved';

lives-ok { $pg.execute('delete from test') }, 'Delete rows';

@cursor = $pg.cursor('select * from test', :hash);

is-deeply @cursor, [], 'No rows from cursor';

lives-ok { $pg.execute('drop table test') }, 'drop table test';

done-testing;
