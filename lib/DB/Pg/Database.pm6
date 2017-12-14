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

    method notify(Str:D $channel, Str:D $extra, Bool :$finish = False)
    {
        self.execute("notify $channel, $!conn.escape-literal($extra)", :$finish);
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
