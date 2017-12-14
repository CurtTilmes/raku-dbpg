use v6;

use Test;
use Test::When <extended>;

use DB::Pg;
use LibUUID;

plan 1;

my $pg = DB::Pg.new;

is-deeply $pg.query("select '5c64e2cf-1750-41c9-a73d-720a78029511'::uuid").value,
    UUID.new('5c64e2cf-1750-41c9-a73d-720a78029511'), 'UUID Object';

done-testing;
