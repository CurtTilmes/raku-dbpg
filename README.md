DB::Pg PostgreSQL access for Perl 6
===================================

First of all, this isn't DBI/DBIish.  If you want that, you know where to find it.  (if you don't,
it's [over here](https://github.com/perl6/DBIish).)

This is a reimplementation of Perl 6 bindings for PostgreSQL's
[libpq](https://www.postgresql.org/docs/current/static/libpq.html).

Whereas DBI and friends like DBIish are a more generic database interface, this one is 
specific to PostgresQL.  If you want to access other databases, go look at DBIish.

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
