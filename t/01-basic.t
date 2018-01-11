use Test;
use Test::When <extended>;

use DB::Pg;

plan 8;

my $pg = DB::Pg.new;

ok $pg, 'Create object';

is $pg.connections.elems, 0, 'No cached connections';

my $db = $pg.db;

ok $db, 'Connect to database';

is $db.query('select 42').value, 42, 'Simple query on db';

$db.finish;

is $pg.connections.elems, 1, 'Connection got returned to cache';

is $pg.query('select 432').value, 432, 'Simple query on pg';

is-deeply $pg.query(q<select 1                               as a,
                            'this'                           as b,
                            2e57                             as c,
                            't'::bool                        as d,
                            '2000-01-01'::date               as e,
                            '2000-01-01 12:34:56'::timestamp as f,
                            '{1,2,3}'::integer[]             as g,
                            '{t,f,null}'::bool[]             as h,
                            '{"a b c", "d e f"}'::text[]     as i>).hash,
    {
        a => 1,
        b => 'this',
        c => 2e57,
        d => True,
        e => Date.new(2000,1,1),
        f => DateTime.new(2000,1,1,12,34,56),
        g => [1, 2, 3],
        h => [True, False, Bool],
        i => ['a b c', 'd e f']
    }, 'Hash of a bunch of types';

is $pg.connections.elems, 1, 'Connection got returned to cache';

done-testing;
