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
