use v6;

use Test;
use Test::When <extended>;

use DB::Pg::Converter;

ok my $c = DB::Pg::Converter.new, 'new converter';

is $c.convert('bool', 't'), True, 'bool t';
is $c.convert('bool', 'f'), False, 'bool f';

is $c.convert([ Q<th\is> ], Array[Str]),
    Q<{"th\\is"}>, 'array with embedded backslash';

done-testing;
