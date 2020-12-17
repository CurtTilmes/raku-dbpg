#!/usr/bin/env raku

use DB::Pg;

my $pg = DB::Pg.new;

my $db = $pg.db;

$db.execute("copy foo from stdin (format csv)");

$db.copy-data("7234,23423\n234234234,963453\n").copy-end;

say $db.query("select * from foo").hashes;

$db.finish;

say $pg.connections.elems;
