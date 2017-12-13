use v6;

use Test;
use Test::When <extended>;

use DB::Pg;
use DB::Pg::TypeConverter::UUID;
use LibUUID;

plan 2;

my $pg = DB::Pg.new;

is $pg.query("select '5c64e2cf-1750-41c9-a73d-720a78029510'::uuid").value,
    '5c64e2cf-1750-41c9-a73d-720a78029510', 'UUID normally a string';

$pg.converter does DB::Pg::TypeConverter::UUID;

is $pg.query("select '5c64e2cf-1750-41c9-a73d-720a78029511'::uuid").value,
    UUID.new('5c64e2cf-1750-41c9-a73d-720a78029511'), 'UUID Object';

done-testing;
