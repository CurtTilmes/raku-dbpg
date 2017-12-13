use v6;
use epoll;
use DB::Pg::Native;
use DB::Pg::TypeConverter;

class DB::Pg::Error is Exception
{
    has $.message;
}

class DB::Pg::Error::EmptyQuery is DB::Pg::Error {}
class DB::Pg::Error::BadResponse is DB::Pg::Error {}
class DB::Pg::Error::BadConnection is DB::Pg::Error {}
class DB::Pg::Error::FatalError is DB::Pg::Error {}    # Not really Fatal..

class DB::Pg::ArrayIterator does Iterator
{
    has $.sth;
    has Bool $.finish;
    has Bool $.hash;
    has Int $.rows;
    has Int $!row = 0;

    method pull-one
    {
        if $!row == $!rows
        {
            $!sth.finish if $!finish;
            return IterationEnd
        }
        $!sth.row($!row++, :$!hash)
    }
}

class DB::Pg::CursorIterator does Iterator
{
    has $.sth;
    has Str $.name;
    has Bool $.hash;
    has Bool $.finish;
    has Int $.rows;
    has Int $!row = 0;

    method pull-one
    {
        try
        {
            if $!rows
            {
                return $!sth.row($!row++, :$!hash) if $!row < $!rows;
                $!sth.execute;
                $!rows = $!sth.rows;
                $!row = 0;
                return self.pull-one;
            }
            else
            {
                $!sth.db.execute("close $!name");
                if $!finish
                {
                    $!sth.db.commit;
                    $!sth.finish
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

class DB::Pg::Results
{
    has Bool $.finish = False;
    has $.sth handles <rows columns types>;

    method finish { $!sth.finish }

    method value
    {
        LEAVE $!sth.finish if $!finish;
        $!sth.row(0)[0]
    }

    method array
    {
        LEAVE $!sth.finish if $!finish;
        $!sth.row(0)
    }

    method hash
    {
        LEAVE $!sth.finish if $!finish;
        $!sth.row(0, :hash) or Nil
    }

    method arrays
    {
        Seq.new: DB::Pg::ArrayIterator.new(:$!sth, :$!finish, :!hash,
                                           rows => $!sth.rows)
    }

    method hashes
    {
        Seq.new: DB::Pg::ArrayIterator.new(:$!sth, :$!finish, :hash,
                                           rows => $!sth.rows)
    }
}

class DB::Pg::Statement
{
    has $.db;
    has $.name;
    has @.paramtypes;
    has @.columns;
    has @.types;
    has PGresult $.result;

    method DESTROY
    {
        .clear with $!result
    }

    method finish
    {
        .clear with $!result;
        $!result = PGresult;
        $!db.finish
    }

    method rows { $!result.tuples }

    method row(Int $row, Bool :$hash)
    {
        return () unless 0 ≤ $row < self.rows;

        my @row = do for ^@!columns.elems Z @!types -> [$col, $type]
        {
            $!result.getisnull($row, $col)
                ?? $type
                !! $!db.converter.convert($type, $!result.getvalue($row, $col))
        }

        $hash ?? %(@!columns Z=> @row) !! @row
    }

    method execute(**@args, Bool :$finish = False, Bool :$decode = True)
    {
        my @params := $!db.converter.convert-params(@args, @!paramtypes, :$!db);

        with $!result { .clear; $!result = PGresult }

        try
        {
            my $result = $!db.error-check:
                $!db.conn.exec-prepared($!name, @params.elems, @params,
                                        Nil, Nil, 0);

            CATCH
            {
                when DB::Pg::Error::EmptyQuery | DB::Pg::Error::FatalError
                {
                    self.finish if $finish;
                    .throw
                }
            }

            given $result.status
            {
                when PGRES_TUPLES_OK
                {
                    $!result = $result;
                    DB::Pg::Results.new(sth => self, :$finish)
                }
                when PGRES_COMMAND_OK
                {
                    $result.clear;
                    self.finish if $finish;
                    $!db
                }
                when PGRES_COPY_IN
                {
                    $result.clear;
                    $!db
                }
                when PGRES_COPY_OUT
                {
                    $result.clear;
                    Seq.new: DB::Pg::CopyOutIterator.new(:$!db,
                                                         :$finish, :$decode);
                }
                default { ... }
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
            $sth.execute;

            return Seq.new: DB::Pg::CursorIterator.new(:$sth, :$name,
                                                       :$hash, :$finish,
                                                       rows => $sth.rows);

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

class DB::Pg
{
    has $.conninfo = '';
    has DB::Pg::TypeConverter $.converter .= new;

    has @.connections;
    has $!connection-lock = Lock.new;

    has $!listen-db;
    has $!listen-db-lock = Lock.new;
    has %!suppliers;
    has $!supplier-lock = Lock.new;

    method db(--> DB::Pg::Database)
    {
        $!connection-lock.protect:
        {
            while @!connections.elems
            {
                my $db = @!connections.pop;

                return $db.active if $db.ping;

                $db.DESTROY;
            }
        }

        loop
        {
            my $conn = PGconn.new($!conninfo);

            die DB::Pg::Error(message => "Can't create connection") unless $conn;

            return DB::Pg::Database.new(conn => $conn, dbpg => self)
                if $conn.status == CONNECTION_OK;

            note $conn.error-message;

            $conn.finish;

            sleep 3;
        }
    }

    method cache(DB::Pg::Database:D $db)
    {
        $!connection-lock.protect: { @!connections.push($db) }
    }

    method query(|args)
    {
        self.db.query(|args, :finish)
    }

    method cursor(|args)
    {
        self.db.cursor(|args, :finish)
    }

    method execute(Str:D $command)
    {
        self.db.execute($command, :finish)
    }

    method notify(Str:D $channel, Str:D $extra)
    {
        self.db.notify($channel, $extra, :finish)
    }

    method !listen-loop
    {
        $!listen-db = self.db;
        my $epoll = epoll.new.add($!listen-db.conn.socket, :in);
        start
        {
            loop
            {
                last unless %!suppliers;
                $!listen-db.conn.consume-input;
                while $!listen-db.conn.notifies -> $notify
                {
                    .emit($notify.extra) with %!suppliers{$notify.relname};
                    $notify.free;
                }
                last unless %!suppliers;
                $epoll.wait;
            }
            $epoll.DESTROY;
            $!listen-db.finish;
            $!listen-db = Nil;
        }
    }

    method listen(Str:D $channel)
    {
        return $_ with %!suppliers{$channel};
        $!supplier-lock.protect: { %!suppliers{$channel} = Supplier.new }
        $!listen-db-lock.protect: { self!listen-loop unless $!listen-db }
        $!listen-db.execute("listen $channel");
        %!suppliers{$channel}
    }

    method unlisten(Str:D $channel)
    {
        return unless $!listen-db && %!suppliers{$channel};
        $!listen-db.execute("unlisten $channel");
        %!suppliers{$channel}.done;
        $!supplier-lock.protect: { %!suppliers{$channel}:delete }
        $!listen-db.execute('select 1');
    }

    method finish
    {
        .DESTROY for @!connections;
        @!connections = ();
    }

    method DESTROY
    {
        self.finish if @!connections;
    }
}
