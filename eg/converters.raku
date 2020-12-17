#!/usr/bin/env raku

use DB::Pg;

my $pg = DB::Pg.new(converters => <DateTime>);

dd $pg.query("select '2000-01-01'::date").value;
