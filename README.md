DB::Pg – PostgreSQL access for Perl 6
=====================================

This is a reimplementation of Perl 6 bindings for PostgreSQL's
[libpq](https://www.postgresql.org/docs/current/static/libpq.html).

Basic usage
-----------

```perl6
my $pg = DB::Pg.new;  # You can pass in connection information if you want.
```
# Example of passing connection information. Thanks to https://gist.github.com/jnthn
# See https://www.postgresql.org/docs/current/static/libpq-connect.html#LIBPQ-CONNSTRING for more on connection information
```perl6
my $conninfo = join " ",
        ('dbname=' ~ (%*ENV<DB_NAME> || die("missing DB_NAME in environemnt"))),
        ("host=$_" with %*ENV<DB_HOST>),
        ("user=$_" with %*ENV<DB_USER>),
        ("password=$_" with %*ENV<DB_PASSWORD>);
my $db = Database.new(:$conninfo, :converters<DateTime>);
```

Execute a query, and get a single value:
```perl6
say $pg.query('select 42').value;
# 42
```

Insert some values using placeholders:
```perl6
$pg.query('insert into foo (x,y) values ($1,$2)', 1, 'this');
```

Note, placeholders use the `$1, $2, ...` syntax instead of `?` See
[PREPARE](https://www.postgresql.org/docs/current/static/sql-prepare.html)
for more information.

Execute a query returning a row as an array or hash;
```perl6
say $pg.query('select * from foo where x = $1', 42).array;
say $pg.query('select * from foo where x = $1', 42).hash;
```

Execute a query returning a bunch of rows as arrays or hashes:
```perl6
.say for $pg.query('select * from foo').arrays;
.say for $pg.query('select * from foo').hashes;
```

If you have no placeholders/arguments and aren't retrieving
information, you can use `execute`.  It does not `PREPARE` the query.

```perl6
$pg.execute('insert into foo (x,y) values (1,2)');
```

Connection Caching
------------------

Database connection handles are created on demand, and cached for
reuse in a connection pool.  Similarly, statement handles are
prepared, cached and reused.

When the first query is called, a new database connection will be
created.  After the results are read from the connection, the
connection will be returned and cached in the pool.  When a later
query is performed, that cached connection will be reused.

If multiple simultaneous queries occur, perhaps in different threads,
each will get a new connection so they won't interfere with one
another.

For example, you can perform database actions while iterating through
results from a query:

```perl6
for $pg.query('select * from foo').hashes -> %h
{
    $pg.query('update bar set ... where x = $1...$2...', %h<x>, %h<y>);
}
```

You can even do arbitrary queries in multiple threads without worrying
about connections:

```perl6
say await do for ^10 {
    start $pg.query('select $1::int, pg_sleep($1::float/10)', $_).value
}
```

Connection caching is a nice convenience, but it does require some
care from the consumer.  If you call `query` with an imperative
statement (`insert`, `update`, `delete`) the connection will
automatically be returned to the pool for re-use.  For a query that
returns results, such as `select`, in order to reliably return the
connection to the pool for the next user, you must do one of two
things:

1. Read all the results.  Once the last returned row is read, the
database connection handle will automatically get returned for reuse.

2. Explicitly call `.finish` on the results object to prematurely return it.

Results
-------

Calling `query` with a `select` or something that returns data, a
`DB::Pg::Results` object will be returned.

The query results can be consumed from that object with the following
methods:

* `.value` - a single scalar result
* `.array` - a single array of results from one row
* `.hash` - a single hash of results from one row
* `.arrays` - a sequence of arrays of results from all rows
* `.hashes` - a sequence of hashes of results from all rows

You can also query for some information about the results on the
object directly:

* `.rows` - Total number of rows returned
* `.columns` - List of column names returned
* `.types` - List of Perl types of columns returned

For example:

```perl6
my $results = $pg.query('select * from foo');

say $results.rows;
say $results.columns;
say $results.types;

.say for $results.hashes;
```

Database
--------

Though you can just call `.query()` on the main `DB::Pg` object,
sometimes you want to explicitly manage the database connection.  Use
the `.db` method to get a `DB::Pg::Database` object, and call
`.finish` explicitly on it to return it to the pool when you are
finished with it.

The database object also has `.query()` and `.execute()` methods, they
just don't automatically `.finish` to return the handle to the pool.
You must explicitly do that after use.

These are equivalent:

```perl6
.say for $pg.query('select * from foo').arrays;
```

```perl6
my $db = $pg.db;
.say for $db.query('select * from foo').arrays;
$db.finish;
```

The database object also has some extra methods for separately
preparing and executing a query:

```perl6
my $db = $pg.db;
my $sth = $db.prepare('insert into foo (x,y) values ($1,$2)');
$sth.execute(1, 'this');
$sth.execute(2, 'that');
$db.finish;
```

`.prepare()` returns a `DB::Pg::Statement` object.

It can be more efficient to perform many actions in this way and avoid
the overhead of returning the connection to the pool only to
immediately get it back again.

Transactions
------------

The database object can also manage transactions with the `.begin`,
`.commit` and `.rollback` methods.

```perl6
my $db = $pg.db;
my $sth = $db.prepare('insert into foo (x,y) values ($1,$2)');
$db.begin;
$sth.execute(1, 'this');
$sth.execute(2, 'that');
$db.commit;
$db.finish;
```

The `begin`/`commit` ensure that the statements between them happen
atomically, either all or none.

Transactions can also dramatically improve performance for some
actions, such as performing thousands of inserts/deletes/updates since
the indices for the affected table can be updated in bulk once for the
entire transaction.

If you `.finish` the database prior to a `.commit`, an uncommitted
transaction will automatically be rolled back.

As a convenience, `.commit` also returns the database object, so you
can just `$db.commit.finish`.

Cursors
-------

When a query is performed, all the results from that query are
immediately returned from the server to the client.  For exceptionally
large queries, this can be problematic, both waiting the time for the
whole query to execute, and the memory for all the
results. [Cursors](https://www.postgresql.org/docs/10/static/plpgsql-cursors.html)
provide a better way.

```perl6
for $pg.cursor('select * from foo where x = $1', 27) -> @row
{
    say @row;
}
```

The `cursor` method will fetch *N* rows at a time from the server (can
be controlled with the `:fetch` parameter, defaults to 1,000).  The
`:hash` parameter can be used to retrieve hashes for the rows instead
of arrays.

```perl6
for $pg.cursor('select * from foo', fetch => 500, :hash) -> %r
{
    say %r;
}
```

Bulk Copy In
------------

PostgreSQL has a
[COPY](https://www.postgresql.org/docs/10/static/sql-copy.html)
facility for bulk copy in and out of the database.

This is accessed with the `DB::Pg::Database` methods `.copy-data` and
`.copy-end`.  Pass blocks of data in with `.copy-data`, and call
`.copy-end` when complete.

```perl6
my $db = $pg.db;
$db.query('copy foo from stdin (format csv)'); # Any valid COPY command
$db.copy-data("1,2\n4,5\n6,12\n")
$db.copy-end;
$db.finish;
```

As a convenience, these methods return the database object, so they
can easily be chained (though you will probably loop the `copy-data`
call.)

```perl6
$pg.db.execute('copy foo from stdin').copy-data("1 2\n12 34234\n").copy-end.finish;
```

Bulk Copy Out
-------------

Bulk copy out can performed too, a COPY command will return a sequence
from an iterator which will return each line:

```perl6
for $pg.query('copy foo to stdout (format csv)') -> $line
{
    print $line;
}
```

Listen/Notify
-------------

PostgreSQL also supports an asynchronous
[LISTEN](https://www.postgresql.org/docs/10/static/sql-listen.html)
command that you can use to receive notifications from the database.
The `.listen()` method returns a supply that can be used within a
`react` block.  You can listen to multiple channels, and all listens
will share the same database connection.

```perl6
react {
    whenever $pg.listen('foo') -> $msg
    {
        say $msg;
    }
    whenever $pg.listen('bar') -> $msg
    {
        say $msg;
    }
}
```

Use `.unlisten` to stop listening to a specific channel.  When the
last listened supply is unlistened, the react block will exit.

```perl6
$pg.unlisten('foo')
```

PostgreSQL notifications can be sent with the `.notify` method:

```perl6
$pg.notify('foo', 'a message');
```

Type Conversions
----------------

The `DB::Pg::Converter` object is used to convert between
PostgreSQL types and Perl types.  It has two maps, one from
[oid](https://www.postgresql.org/docs/current/static/datatype-oid.html)
types to PostgreSQL type names, and one from the type names to Perl
types.

For example, the oid `23` maps to the PostgreSQL type `int` which maps
to the Perl type `Int`.

`DB::Pg::Converter` has a multiple dispatch method `convert()`
that is used to convert types.

Extra roles can be mixed in to the default converter to enable it to
convert to and from other types.

The `converter()` method on the main `DB::Pg` object will return the
current converter, then `does` can be used to add a role with extra
conversion methods.

Here is a short example that causes the PostgreSQL 'json' and 'jsonb'
types to be converted automatically.

```perl6
use DB::Pg;
use JSON::Fast;

my $pg = DB::Pg.new;

my class JSON {}  # Just a fake type, since JSON uses native Perl arrays/hashes

$pg.converter does role JSONConverter
{
    submethod BUILD { self.add-type(json => JSON, jsonb => JSON) }
    multi method convert(JSON:U, Str:D $value) { from-json($value) }
    multi method convert(Mu:D $value, JSON:U) { to-json($value) }
}
```

There are three parts to this conversion.  First the `BUILD` adds the
type mappings, then there are two methods, the first converts from a
string (`Str:D`) to a `JSON:U` type.  The second will be used when a
parameter requires a JSON object.  If the object already has a `Str`
method that results in a suitable string for PostgreSQL (often the
case), the second method can be omitted.  (Or if you are only reading
a type from the database, and never passing it to the server.)

Several Converters are bundled with this module, and by default
they are added to the Converter automatically:

* DateTime (date, timestamp, timestamptz -> Date, DateTime)
* JSON (json, jsonb)
* UUID (uuid -> UUID via LibUUID)
* Geometric (point, line, lseg, box, path, polygon, circle)

The Geometric types are available in `DB::Pg::GeometricTypes`.

If you *don't* want any of those converters, just pass in an empty
`converters` array, or with just the ones you want:

```perl6
my $pg = DB::Pg.new(converters => <DateTime JSON>)
```

If you want a different type of conversion than those canned types,
just exclude the default one and install your own as above.

Note: I'm looking for better ways to arrange this -- comments (file an
issue) welcome!

Arrays
------

Most types of arrays are handled by default.  When selecting, they
will be converted to Perl Array objects.  Likewise, to pass arrays to
the server, just pass a Perl Array object.

Exceptions
----------

All database errors, including broken SQL queries, are thrown as exceptions.

NOTE
----

For now, I've got the async pub/stuff using epoll, which is Linux
specific, so this is tied to Linux.  Patches welcome!

Acknowledgements
----------------

Inspiration taken from the existing Perl6
[DBIish](https://github.com/perl6/DBIish) module as well as the Perl 5
[Mojo::Pg](http://mojolicious.org/perldoc/Mojo/Pg) from the
Mojolicious project.

License
-------

See [NASA Open Source Agreement](../master/NASA_Open_Source_Agreement_1.3%20GSC-18031.pdf) for more details.

Copyright
---------

Copyright © 2017 United States Government as represented by the
Administrator of the National Aeronautics and Space Administration.
No copyright is claimed in the United States under Title 17,
U.S.Code. All Other Rights Reserved.
