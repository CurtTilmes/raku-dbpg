#!/usr/bin/env perl6

use DB::Pg;
use NativeCall;

my $pg = DB::Pg.new;

say "MAIN is $*THREAD.id()";

await do for ^5
{
    start {
        say $pg.do('select generate_series(1,10)').arrays.flat;
    }
}
