DB::Pg PostgreSQL access for Perl 6
===================================

First of all, this isn't DBI/DBIish.  If you want that, you know where to find
it.  (if you don't, it's [over here](https://github.com/perl6/DBIish).)

This is a reimplementation of Perl 6 bindings for PostgreSQL's
[libpq](https://www.postgresql.org/docs/current/static/libpq.html).

Whereas DBI and friends like DBIish are a more generic database interface, this
one is specific to PostgresQL.  If you want to access other databases, go look
at DBIish.

Basic usage
-----------

```
my $pg = DB::Pg.new;  # You can pass in connection information if you want.
```

Execute a query, and get a single value
```
say $pg.query('select 42').value;
# 42
```

```do``` is just an alias for ```query```.

```
$pg.do('insert into foo (x,y) values ($1,$2)', 1, 'this');
```

Note, placeholders use the ```$1, $2, ...``` syntax instead of ```?``` See
[PREPARE](https://www.postgresql.org/docs/current/static/sql-prepare.html) for
more information.

Connection Caching
------------------

Database connection handles are created on demand, and cached for reuse.
Similarly, statement handles are prepared, cached and reused.

When the first query is called, a new database connection will be created.
After the results are read from the connection using the ```.value``` call,
the connection will be returned and cached.  When the ```insert``` call is
made, that cached connection will be reused for that query.

If multiple simultaneously queries occur, perhaps in different threads, each
will get a new connection so they won't interfere with one another.

Connection caching is a nice convenience, but it does require some care from
the consumer.  If you call ```query``` (or ```do```) with an imperative statement
(```insert```, ```update```, ```delete```) the connection will automatically
be returned to the cache for re-use.  For a query that returns results, such as
```select```, in order to reliably return the connection to the pool for the 
next user, you must do one of two things:

1. Read all the results.  Once the last returned row is read, the database
connection handle will automatically get returned for reuse.

2. Explicitly call ```.finish``` on the results object to prematurely return it.

Results
-------

Calling ```query``` (or ```do```) with a ```select``` or something that returns
data, a ```DB::Pg::Results``` object will be returned.

The query results can be consumed from that object with the following methods:

* ```.value``` - a single scalar result
* ```.array``` - a single array of results from one row
* ```.hash``` - a single hash of results from one row
* ```.arrays``` - a sequence of arrays of results from all rows
* ```.hashes``` - a sequence of hashes of results from all rows

You can also query for some information about the results on the object
directly:

* ```.rows``` - Total number of rows returned
* ```.columns``` - List of column names returned
* ```.types``` - List of Perl types of columns returned

For example:

```
my $results = $pg.query('select * from foo');

say $results.rows;
say $results.columns;
say $results.types;

.say for $results.hashes;
```

Database
--------

Though you can just call ```.query()``` on the main ```DB::Pg``` object,
sometimes you want to explicitly manage the database connection.  Use the
```.db``` method to get a ```DB::Pg::Database``` object, and call ```.finish```
explicitly on it to return it to the cache when you are finished with it.

The database object also has a ```.query()``` method, it just doesn't return
the connection.

These are equivalent:

```
.say for $pg.query('select * from foo').arrays;
```

```
my $db = $pg.db;
.say for $db.query('select * from foo').arrays;
$db.finish;
```

The database object also has some extra methods for separately preparing
and executing a query:

```
my $db = $pg.db;
my $sth = $db.prepare('insert into foo (x,y) values ($1,$2)');
$sth.execute(1, 'this');
$sth.execute(2, 'that');
$db.finish;
```

Transactions
------------

The database object can also manage transactions with the ```.begin```,
```.commit``` and ```.rollback``` methods.

```
my $db = $pg.db;
my $sth = $db.prepare('insert into foo (x,y) values ($1,$2)');
$db.begin;
$sth.execute(1, 'this');
$sth.execute(2, 'that');
$db.commit;
$db.finish;
```

The ```begin```/```commit``` ensure that the statements between them happen
atomically, either all or none.

Transactions can also dramatically improve performance for some actions,
such as performing thousands of inserts/deletes/updates since the indices
for the affected table can be updated in bulk once for the entire transaction.

If you ```.finish``` the database prior to a ```.commit```, an uncommitted
transaction will automatically be rolled back.

Cursors
-------

When a query it performed, all the results from that query are immediately
returned from the server to the client.  For exceptionally large queries, this
can be problematic, both for the time of the query, and the memory for all
the results. [Cursors](https://www.postgresql.org/docs/10/static/plpgsql-cursors.html)
provide a better way.

Bulk Copy In
------------

PostgreSQL has a [copy](https://www.postgresql.org/docs/10/static/sql-copy.html)
facility for bulk copy in and out of the database.

This is accessed with the ```DB::Pg::Database``` methods ```.copy-data``` and 
```.copy-end```.  Pass blocks of data in with ```.copy-data```, and call
```.copy-end``` when complete.

```
my $db = $pg.db;
$db.execute('copy foo from stdin (format csv)'); # Any valid COPY command
$db.copy-data("1,2\n4,5\n6,12\n")
$db.copy-end;
$db.finish;
```

As a convenience, these methods return the database object, so they can
easily be chained (though you will probably loop the ```copy-data``` call.)

```
my $db = $pg.db.execute('copy foo from stdin');
$db.copy-data("1 2\n12 34234\n").copy-end.finish;
```

Bulk Copy Out
-------------

Bulk copy out can performed too, a COPY command will return a sequence from
an iterator which will return each line:

```
for $pg.execute('copy foo to stdout (format csv)') -> $line
{
    print $line;
}
```

Listen/Notify
-------------
PostgreSQL also supports an asynchronous
[LISTEN](https://www.postgresql.org/docs/10/static/sql-listen.html)
command that you can use to receive notifications from the database.  
The ```.listen()``` method returns a supply that can be used within a
```react``` block.  You can listen to multiple channels, and all listens
will share the same database connection.

```
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

Use ```.unlisten``` to stop listening to a specific channel.  When
the last listened supply is unlistened, the react block will exit.

```
$pg.unlisten('foo')
```

Type Conversions
----------------

Arrays
------

Exceptions
----------

All database errors, including broken SQL queries, are thrown as exceptions.
