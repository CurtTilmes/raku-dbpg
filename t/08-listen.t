use v6;

use Test;
use Test::When <extended>;

use DB::Pg;

#plan 8;

my $pg = DB::Pg.new;

my @foo;
my @bar;

my $p = start react
{
    whenever $pg.listen('foo') -> $msg
    {
        @foo.push($msg)
    }
    whenever $pg.listen('bar') -> $msg
    {
        @bar.push($msg)
    }
}

sleep 1;

for ^5
{
    lives-ok { $pg.notify('foo', "$_ foo") }, "notify foo $_";
    lives-ok { $pg.notify('bar', "$_ bar") }, "notify bar $_";
}

sleep 1;

lives-ok { $pg.unlisten('bar') }, 'unlisten bar';

for 5..^10
{
    lives-ok { $pg.notify('foo', "$_ foo") }, "notify foo $_";
    lives-ok { $pg.notify('bar', "$_ bar") }, "notify bar $_";
}

sleep 1;

lives-ok { $pg.unlisten('foo') }, 'unlisten foo';

await $p;

is-deeply @foo, ["0 foo", "1 foo", "2 foo", "3 foo", "4 foo",
                 "5 foo", "6 foo", "7 foo", "8 foo", "9 foo" ], 'check foo';

is-deeply @bar, ["0 bar", "1 bar", "2 bar", "3 bar", "4 bar" ], 'check bar';

done-testing;
