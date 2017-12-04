use v6;

use Test;
use Test::When <extended>;

use DB::Pg;

plan 4;

my $pg = DB::Pg.new;

is-deeply $pg.query('select generate_series(1,5)').arrays,
    ([1],[2],[3],[4],[5]), 'Arrays';

is-deeply $pg.query('select generate_series(1,5) as x').hashes,
    ({x => 1}, {x => 2}, {x => 3}, {x => 4}, {x => 5}), 'Hashes';

is-deeply $pg.query('select generate_series(1,0)').arrays, (), 'No arrays';

is-deeply $pg.query('select generate_series(1,0)').hashes, (), 'No hashes';

done-testing;
