use Test;
use Test::When <extended>;

use DB::Pg;

plan 4;

my $pg = DB::Pg.new;

is-deeply $pg.query(q<select '{1,2,3}'::integer[]>).value,
    [1,2,3], 'Array of int';

is-deeply $pg.query(q<select '{1.2, 2, 3e42}'::float8[]>).value,
    [1.2e0, 2e0, 3e42], 'Array of float';

is-deeply $pg.query(q<select '{this,that}'::text[]>).value,
    [<this that>], 'Array of str';

is-deeply $pg.query(q<select '{t,f,null}'::bool[]>).value,
    [True, False, Bool], 'Array of bool';

done-testing;
