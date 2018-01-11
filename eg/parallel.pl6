#!/usr/bin/env perl6

use DB::Pg;

my $pg = DB::Pg.new;

say await do for ^10
{
    start $pg.query('select $1::int, pg_sleep($1::float/10)', $_).value
}
