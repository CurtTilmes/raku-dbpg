use v6;

use Test;
use Test::When <extended>;

use DB::Pg;
use DB::Pg::Converter::DateTime;

plan 1;

my $pg = DB::Pg.new;

$pg.converter does DB::Pg::Converter::DateTime;

is-deeply $pg.query("select '2000-01-01'::date as a,
                            '2000-01-01 12:34:56'::timestamp as b").array,
    [ Date.new(2000,1,1), DateTime.new(2000,1,1,12,34,56) ], 'DateTime';

done-testing;
