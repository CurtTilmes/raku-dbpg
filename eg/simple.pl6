#!/usr/bin/env perl6

use DB::Pg;

my $pg = DB::Pg.new;

say $pg.query("select 'foobar'").value;


say "done";

say $pg.connections.elems;
