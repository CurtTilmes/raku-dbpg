#!/usr/bin/env perl6

use DB::Pg;

my $pg = DB::Pg.new;

for $pg.cursor("select * from generate_series(1,10) as val", :hash, :finish) -> $row
{
    say $row;
}

say "done";

say $pg.connections.elems;
