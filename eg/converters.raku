#!/usr/bin/env perl6

use DB::Pg;


my $pg = DB::Pg.new(converters => <DateTime>);

dd $pg.query("select '2000-01-01'::date").value;
