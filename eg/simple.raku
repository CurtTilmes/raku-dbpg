#!/usr/bin/env raku

use DB::Pg;

my $pg = DB::Pg.new;

say $pg.query("select version()").value;
