use Test;
use Test::When <extended>;

use DB::Pg::Converter;

ok my $c = DB::Pg::Converter.new, 'new converter';

is $c.convert('bool', 't'), True, 'bool t';
is $c.convert('bool', 'f'), False, 'bool f';

is $c.convert([ 'th"is' ], Array[Str]),
    Q<{"th\"is"}>, 'array with quote';

is $c.convert([ Q<th\is> ], Array[Str]),
    Q<{"th\\is"}>, 'array with embedded backslash';

is $c.convert([1,2,3], Array[Int]), Q<{1,2,3}>, 'Array';

is $c.convert((1,2,3), Array[Int]), Q<{1,2,3}>, 'List';

is $c.convert([[1,2],[3,4]], Array[Int]), Q<{{1,2},{3,4}}>, 'Array of Array';

is $c.convert([(1,2),(3,4)], Array[Int]), Q<{{1,2},{3,4}}>, 'Array of List';

is $c.convert(['this', Nil], Array[Str]), Q<{"this",NULL}>,
    'Array of Str with Nil';

done-testing;
