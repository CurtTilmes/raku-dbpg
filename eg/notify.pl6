#!/usr/bin/env perl6

use NativeCall;
use DB::Pg;

my $pg = DB::Pg.new;

react
{
    whenever $pg.listen('foo') -> $msg
    {
        say $msg;
    }

    whenever $pg.listen('bar') -> $msg
    {
        say $msg;
    }
}

