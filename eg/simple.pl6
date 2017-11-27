#!/usr/bin/env perl6

use NativeCall;
use DB::Pg;

my $pg = DB::Pg.new;

say $pg.query("select version()").value;

