use v6;

use Test;
use Test::When <extended>;

use DB::Pg::TypeConverter;
use DB::Pg::ArrayParser;

plan 11;

my $converter = DB::Pg::TypeConverter.new;

sub parseit($type, $str)
{
    my $*converter = $converter;
    my $*type = $type;
    DB::Pg::ArrayParser.parse($str,
                              actions => DB::Pg::ArrayActions).made
}

is-deeply parseit(Int, '{42}'), [42], 'Int';

is-deeply parseit(Int, '{1,2,3}'), [1,2,3], 'Int array';

is-deeply parseit(Str, '{42}'), ['42'], 'Str';

is-deeply parseit(Num, '{11e542}'), [11e542], 'Num';

is-deeply parseit(Int, '{ { 1, 2 }, { 3, 4 } }'), [[ 1,2 ], [3,4]], 'Int[]';

is-deeply parseit(Str, '{ { 42, "this", abc }, { a, b, c } }'),
                  [['42', 'this', 'abc'],['a', 'b', 'c']], 'nested';

is-deeply parseit(Str, '{"this that"}'), ['this that'], 'embedded space';

is-deeply parseit(Str, '{ "this\"that" }'), ['this"that'], 'embedded quote';

is-deeply parseit(Str, Q'{ "this\\that" }'), ['this\that'], 'embedded backslash';

is-deeply parseit(Int, '{ NULL, 7, NULL }'), [Int, 7, Int], 'Int nulls';

is-deeply parseit(Str, '{ NULL, 7, NULL }'), [Str, '7', Str], 'Str nulls';

done-testing;
