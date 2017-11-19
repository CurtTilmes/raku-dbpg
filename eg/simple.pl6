#!/usr/bin/env perl6

use DB::Pg;

my $pg = DB::Pg.new;

my $db = $pg.db;

prompt('now');

try say $db.query("select 'foobar'").value;

say $!.perl;

$db.finish;


say "done";

say $pg.connections.elems;
