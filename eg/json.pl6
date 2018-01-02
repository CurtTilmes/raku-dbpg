#!/usr/bin/env perl6

use DB::Pg;
use DB::Pg::Converter::JSON;

my $pg = DB::Pg.new;

$pg.converter does DB::Pg::Converter::JSON;

dd  $pg.query(Q<select '{"a":12,"b":"this"}'::json>).value;
