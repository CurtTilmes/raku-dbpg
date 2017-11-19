#!/usr/bin/env perl6

use DB::Pg;

my $pg = DB::Pg.new;

$pg.db.query('insert into foo values (1)');

$pg.db.query('insert into foo values (2)').finish;

$pg.db.query('insert into foo values (3)');


say $pg.connections.elems;
