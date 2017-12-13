use v6;

use Test;
use Test::When <extended>;

use DB::Pg::Native;

plan 10;

ok PQlibVersion, 'PQlibVersion';

ok my $pgconn = PGconn.new, 'New Connection';

is $pgconn.status, CONNECTION_OK, 'status';

ok my $result = $pgconn.exec('select 42 as val'), 'exec';

is $result.status, PGRES_TUPLES_OK, 'result status';

is $result.tuples, 1, 'tuples';

is $result.fields, 1, 'fields';

is $result.field-name(0), 'val', 'field-name';

is $result.field-type(0), 23, 'field-type';

is $result.getvalue(0,0), 42, 'getvalue';

$result.clear;

$pgconn.finish;

done-testing;
