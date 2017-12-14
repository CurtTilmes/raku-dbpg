use DB::Pg::Native;
use DB::Pg::Statement;

class DB::Pg::CursorIterator does Iterator
{
    has DB::Pg::Statement $.sth;
    has Str $.name;
    has Bool $.hash;
    has Bool $.finish;
    has Int $!rows;
    has Int $!row;
    has DB::Pg::Results $!res;

    submethod TWEAK { self.fetch }

    method fetch
    {
        try
        {
            .clear with $!res;
            $!res = $!sth.execute;

            CATCH
            {
                when DB::Pg::Error::EmptyQuery | DB::Pg::Error::FatalError
                {
                    $!sth.finish if $!finish;
                    .throw;
                }
            }
        }
        $!rows = $!res.rows;
        $!row = 0;
    }

    method pull-one
    {
        try
        {
            if $!rows
            {
                return $!res.row($!row++, :$!hash) if $!row < $!rows;
                self.fetch;
                return self.pull-one;
            }
            else
            {
                $!sth.db.execute("close $!name");
                if $!finish
                {
                    $!sth.db.commit;
                    $!res.finish;
                }
                return IterationEnd
            }
            CATCH
            {
                when DB::Pg::Error::EmptyQuery | DB::Pg::Error::FatalError
                {
                    $!sth.finish if $!finish;
                    .throw;
                }
            }
        }
    }
}

class DB::Pg::Database
{
    has PGconn $.conn;
    has $.dbpg;
    has %!prepare-cache;
    has $!counter = 0;
    has Bool $!active = True;
    has $!transaction = False;

    method DESTROY
    {
        %!prepare-cache = ();
        .finish with $!conn;
        $!conn = PGconn;
        $!active = False;
    }

    method ping { $!conn.status == CONNECTION_OK }

    method active { $!active = True; self }

    method converter { $!dbpg.converter }

    method finish
    {
        if $!conn.status == CONNECTION_BAD
        {
            self.DESTROY
        }
        elsif $!active
        {
            if $!transaction
            {
                self.rollback;
                $!transaction = False;
            }
            $!active = False;
            $!dbpg.cache(self);
        }
    }

    multi method error-check(PGresult:U $result)
    {
        die DB::Pg::Error.new(message => $!conn.error-message);
    }

    multi method error-check(PGresult:D $result)
    {
        given $result.status
        {
            when PGRES_EMPTY_QUERY {
                $result.clear;
                die DB::Pg::Error::EmptyQuery.new(message => 'Empty Query')
            }
            when PGRES_FATAL_ERROR {
                $result.clear;
                die DB::Pg::Error::FatalError.new(
                    message => $!conn.error-message)
            }
            when PGRES_COMMAND_OK|PGRES_TUPLES_OK|PGRES_COPY_OUT|PGRES_COPY_IN {
                $result
            }
            default {...}
        }
    }

    method prepare(Str:D $query --> DB::Pg::Statement)
    {
        die "Not active" unless $!active;

        return $_ with %!prepare-cache{$query};

        my $name = "statement_{$!counter++}";

        my $result = self.error-check: $!conn.prepare($name, $query, 0, Nil);

        $result.clear;

        $result = self.error-check: $!conn.describe-prepared($name);

        my @paramtypes = (^$result.params)
            .map({ $.converter.type($result.param-type($_)) });

        my @columns = (^$result.fields).map({ $result.field-name($_) });

        my @types = (^$result.fields)
            .map({ $.converter.type($result.field-type($_)) });

        $result.clear;

        %!prepare-cache{$query} = DB::Pg::Statement.new(:db(self), :$name,
                                                        :@paramtypes, :@columns,
                                                        :@types);
    }

    method execute(Str:D $command, Bool :$finish = False, Bool :$decode = True)
    {
        my $result = self.error-check($!conn.exec($command));
        given $result.status
        {
            when PGRES_COPY_OUT
            {
                $result.clear;
                Seq.new: DB::Pg::CopyOutIterator.new(db => self,
                                                     :$finish, :$decode);
            }
            when PGRES_COPY_IN
            {
                $result.clear;
                self
            }
            default
            {
                $result.clear;
                self.finish if $finish;
            }
        }
    }

    multi method copy-data(Blob:D $data)
    {
        if $!conn.put-copy-data($data, $data.bytes) == -1
        {
            die DB::Pg::Error(message => $!conn.error-message);
        }
        self
    }

    multi method copy-data(Str:D $data)
    {
        self.copy-data($data.encode);
    }

    multi method copy-end(Str $error = Str)
    {
        if $!conn.put-copy-end($error) == -1
        {
            die DB::Pg::Error(message => $!conn.error-message);
        }
        self.error-check($!conn.get-result).clear;
        self
    }

    method query(Str:D $query, Bool :$finish = False, |args)
    {
        try
        {
            return self.prepare($query).execute(|args, :$finish);

            CATCH
            {
                when DB::Pg::Error::EmptyQuery | DB::Pg::Error::FatalError
                 {
                     self.finish if $finish;
                     .throw;
                }
            }
        }
    }

    method begin
    {
        self.execute('begin');
        $!transaction = True;
        self
    }

    method commit
    {
        die "Not in a transaction" unless $!transaction;
        self.execute('commit');
        $!transaction = False;
        self
    }

    method rollback
    {
        self.execute('rollback');
        $!transaction = False;
        self
    }

    method notify(Str:D $channel, Str:D $message, Bool :$finish = False)
    {
        self.execute("notify $channel, $!conn.escape-literal($message)",
                     :$finish);
    }

    method cursor(Str $query, *@args, Bool :$finish = False, Bool :$hash = False,
                  Int :$fetch = 1000)
    {
        try
        {
            self.begin if !$!transaction;

            my $name = "cursor_{$!counter++}";
            self.query("declare $name cursor for $query", |@args);

            my $sth = self.prepare("fetch $fetch from $name");

            return Seq.new: DB::Pg::CursorIterator.new(:$sth, :$name,
                                                       :$hash, :$finish);

            CATCH
            {
                when DB::Pg::Error::EmptyQuery | DB::Pg::Error::FatalError
                 {
                     self.finish if $finish;
                     .throw;
                }
            }
        }
    }
}

=begin pod

=head1 NAME

DB::Pg::Database -- Database object

=head1 SYNOPSIS

 my $pg = DB::Pg.new;

 my $db = $pg.db;

 say "Good connection" if $db.ping;

 say $db.query('select * from foo where x = $1', 27).hash;

 my $sth = $db.prepare('select * from foo where x = $1'); # DB::Pg::Statement

 $db.execute('insert into foo (x,y) values (1,2)'); # No args, no return

 $db.begin;

 $db.query('copy foo from stdin (format csv)');
 $db.copy-data("1,2\n");
 $db.copy-end;

 $db.commit;

 $db.notify('foo', 'message');

 for $db.cursor('select * from foo') -> @row
 {
     say @row
 }

 $db.finish; # Finished with database, return to idle pool

=head1 DESCRIPTION

Always allocate from a C<DB::Pg> object with the C<.db> method.  Use
C<.finish> to return the database connection to the pool when
finished.

=head1 METHODS

=head2 B<finish>()

Return this database connection to the connection pool in the parent
C<DB::Pg> object.

=head2 B<ping>()

Returns True if the connection to the server is good.

=head2 B<execute>(Str:D $sql, Bool :finish)

Execute an SQL statement which requires no arguments and returns
nothing.  This can be used for SQL COPY commands.

If :finish is True, the database connection will be C<finish>ed after
the command executes.

=head2 B<prepare>(Str:D $query --> DB::Pg::Statement)

Prepares the SQL query, returning a C<DB::Pg::Statement> object with
the prepared query.  These are cached in the database object, so if
the same query is prepared again, the previous statement is returned.

=head2 B<query>(Str:D $query, *@args, Bool :finish)

prepares, then executes the query with the supplied arguments.

=head2 B<begin>()

Begins a new database transaction

Returns the C<DB::Pg::Database> object.

=head2 B<commit>()

Commits an active database transaction

Returns the C<DB::Pg::Database> object.

=head2 B<rollback>()

Rolls back an active database transaction.  If the database is
finished with an active transaction, it will be rolled back
automatically.

Returns the C<DB::Pg::Database> object.

=head2 B<cursor>(Str:D $sql, *@args, Bool :hash, Int :fetch, Bool :finish)

Creates and returns the cursor sequence.  B<:fetch> defaults to 1000
rows per database fetch.  B<:hash> returns hashes for rows instead of
arrays.

If :finish is true, C<finish>es the database connection.

=head2 B<notify>(Str:D $channel, Str:D $message, Bool :finish)

Issues a PostgreSQL NOTIFY on the specified channel.

If :finish is true, C<finish>es the database connection.

=head2 B<copy-data>($data)

Following an SQL COPY command, this can be used to send bulk data to
the server.  C<$data> can be either a C<Blob> of raw data, or a
C<Str>.  If it is a string, it is encoded as UTF-8 first.

Returns the C<DB::Pg::Database> object.

=head2 B<copy-end>(Str $error)

Ends a COPY sequence.  If $error is set, the COPY fails with the
supplied error, throwing an Exception.

Returns the C<DB::Pg::Database> object.

=end pod
