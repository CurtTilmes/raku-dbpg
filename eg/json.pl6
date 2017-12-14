#!/usr/bin/env perl6

use DB::Pg;
use DB::Pg::TypeConverter::JSON;

my $pg = DB::Pg.new;

$pg.converter does DB::Pg::TypeConverter::JSON;

dd  $pg.query(Q<select '{"a":12,"b":"this"}'::json>).value;
