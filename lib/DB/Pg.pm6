use NativeCall;
use epoll;

constant LIB = 'pq';  # libpq.so

enum ConnStatusType <
    CONNECTION_OK
    CONNECTION_BAD
>;

enum ExecStatusType <
    PGRES_EMPTY_QUERY
    PGRES_COMMAND_OK
    PGRES_TUPLES_OK
    PGRES_COPY_OUT
    PGRES_COPY_IN
    PGRES_BAD_RESPONSE
    PGRES_NONFATAL_ERROR
    PGRES_FATAL_ERROR
    PGRES_COPY_BOTH
    PGRES_SINGLE_TUPLE
>;

# Taken from DBDish::Pg::Native
constant %oid-to-type = Map.new(
        16  => Bool,  # bool
        17  => Buf,   # bytea
        18  => Str,   # char
        19  => Str,   # name
        20  => Int,   # int8
        21  => Int,   # int2
        23  => Int,   # int4
        25  => Str,   # text
        26  => Str,   # oid
       114  => Str,   # json
       142  => Str,   # xml
       700  => Num,   # float4
       701  => Num,   # float8
       705  => Any,   # unknown
       790  => Str,   # money
      1000  => Bool,  # _bool
      1001  => Buf,   # _bytea
      1005  => Array[Int],     # Array(int2)
      1007  => Array[Int],     # Array(int4)
      1009  => Array[Str],     # Array(text)
      1015  => Str,            # _varchar
      1021  => Array[Num],     # Array(float4)
      1022  => Array[Num],     # Array(float4)
      1028  => Array[Int],     # Array<oid>
      1042  => Str,            # char(bpchar)
      1043  => Str,            # varchar
      1082  => Date,           # date
      1083  => Str,            # time
      1114  => DateTime,       # Timestamp
      1184  => DateTime,       # Timestamp with time zone
      1186  => Duration,       # interval
      1263  => Array[Str],     # Array<varchar>
      1700  => Rat,   # numeric
      2950  => Str,   # uuid
      2951  => Str,   # _uuid
);

sub PQlibVersion(-->uint32) is native(LIB) {}
sub PQfreemem(Pointer) is native(LIB) {}

class PGresult is repr('CPointer')
{
    method PQresultStatus(--> int32)
        is native(LIB) {}

    method status(--> ExecStatusType) { ExecStatusType(self.PQresultStatus) }

    method error-message(--> Str) is native(LIB)
        is symbol('PQresultErrorMessage') {}

    method clear() is native(LIB)
        is symbol('PQclear') {}

    method tuples(--> int32)
        is native(LIB) is symbol('PQntuples') {}

    method fields(--> int32)
        is native(LIB) is symbol('PQnfields') {}

    method field-name(int32 $column_number --> Str)
        is native(LIB) is symbol('PQfname') {}

    method field-type(int32 $column_number --> uint32)
        is native(LIB) is symbol('PQftype') {}

    method getvalue(int32 $row_number, int32 $column_number --> Str)
        is native(LIB) is symbol('PQgetvalue') {}

    method getisnull(int32 $row_number, int32 $column_number --> int32)
        is native(LIB) is symbol('PQgetisnull') {}

    method getlength(int32 $row_number, int32 $column_number --> int32)
        is native(LIB) is symbol('PQgetlength') {}

    method params(--> int32)
        is native(LIB) is symbol('PQnparams') {}

    method param-type(int32 $param_number--> uint32)
        is native(LIB) is symbol('PQparamtype') {}

    method format(int32 $column_number --> int32)
        is native(LIB) is symbol('PQfformat') {}
}

class PGnotify is repr('CStruct')
{
    has Str   $.relname;
    has int32 $.be_pid;
    has Str   $.extra;

    method free { PQfreemem(nativecast(Pointer,self)) }
}

class PGconn is repr('CPointer')
{
    sub PQconnectdb(Str $conninfo --> PGconn)
        is native(LIB) {}

    method new(Str $conninfo = '') { PQconnectdb($conninfo ) }

    method finish()
        is native(LIB) is symbol('PQfinish') {}

    method PQstatus(--> int32)
        is native(LIB) {}

    method status(--> ConnStatusType) { ConnStatusType(self.PQstatus) }

    method error-message(--> Str)
        is native(LIB) is symbol('PQerrorMessage') {}

    method get-result(--> PGresult)
        is native(LIB) is symbol('PQgetResult') {}

    method socket(--> int32)
        is native(LIB) is symbol('PQsocket') {}

    method prepare(Str $stmtName,Str $query,int32 $nParams,
                   CArray[uint32] $paramTypes --> PGresult)
        is native(LIB) is symbol('PQprepare') {}

    method describe-prepared(Str $stmtName --> PGresult)
        is native(LIB) is symbol('PQdescribePrepared') {}

    method exec(Str $command --> PGresult)
        is native(LIB) is symbol('PQexec') {}

    method exec-prepared(Str $stmtName, int32 $nParams,
                         CArray[Str] $paramValues,
                         CArray[int32] $paramLengths,
                         CArray[int32] $paramFormats,
                         int32 $resultFormat --> PGresult)
        is native(LIB) is symbol('PQexecPrepared') {}

    method get-copy-data(Pointer $ptr is rw, int32 $async --> int32)
        is native(LIB) is symbol('PQgetCopyData') {}

    method put-copy-data(Blob $blob, int32 $nbytes --> int32)
        is native(LIB) is symbol('PQputCopyData') {}

    method put-copy-end(Str $errormsg --> int32)
        is native(LIB) is symbol('PQputCopyEnd') {}

    method consume-input(--> int32)
        is native(LIB) is symbol('PQconsumeInput') {}

    method PQescapeIdentifier(Blob $blob, size_t $length --> Pointer)
        is native(LIB) is symbol('PQescapeIdentifier') {}

    method PQescapeLiteral(Blob $blob, size_t $length --> Pointer)
        is native(LIB) is symbol('PQescapeLiteral') {}

    method escape-literal(Str $str --> Str)
    {
        my $buf = $str.encode;
        with self.PQescapeLiteral($buf, $buf.bytes)
        {
            LEAVE PQfreemem($_);
            nativecast(Str, $_);
        }
        else
        {
            Nil
        }
    }

    method PQtrace(Pointer $debug_port)
        is native(LIB) {}

    sub fopen(Str $path, Str $mode --> Pointer)
        is native {}

    method trace(Str $path) { self.PQtrace(fopen($path, 'a')) }

    method untrace()
        is native(LIB) is symbol('PQuntrace') {}

    method notifies(--> PGnotify)
        is native(LIB) is symbol('PQnotifies') {}
}

class DB::Pg::Error is Exception
{
    has $.message;
}

class DB::Pg::Error::EmptyQuery is DB::Pg::Error {}
class DB::Pg::Error::BadResponse is DB::Pg::Error {}
class DB::Pg::Error::BadConnection is DB::Pg::Error {}
class DB::Pg::Error::FatalError is DB::Pg::Error {}    # Not really Fatal..

class DB::Pg::Results
{
    has Bool $.finishflag = False;
    has $.sth handles <row rows columns types finish>;

    method value
    {
        LEAVE self.finish if $!finishflag;
        $!sth.row()[0]
    }

    method array
    {
        LEAVE self.finish if $!finishflag;
        $!sth.row
    }

    method hash
    {
        LEAVE self.finish if $!finishflag;
        $!sth.row(:hash)
    }

    method arrays
    {
        gather
        {
            while $!sth.row(finish => $!finishflag) -> $_ { .take }
        }
    }

    method hashes
    {
        gather
        {
            while $!sth.row(:hash, finish => $!finishflag) -> $_ { .take }
        }
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
    has Int $.rows;
    has Int $!row;

    method DESTROY
    {
        .clear with $!result;
    }

    method finish
    {
        .clear with $!result;
        $!result = PGresult;
        $!rows = 0;
        $!db.finish;
    }

    method row(Bool :$hash, Bool :$finish)
    {
        LEAVE { self.finish if (++$!row == $!rows) && $finish }

        (return $hash ?? {} !! ()) unless $!row < $!rows;

        my @row = do for ^@!columns.elems Z @!types -> [$col, $type]
        {
            $!result.getisnull($!row, $col)
                ?? $type
                !! $!result.getvalue($!row, $col)
        }

        $hash ?? %(@!columns Z=> @row) !! @row
    }

    method execute(*@args, Bool :$finish = False)
    {
        my @params := CArray[Str].new;

        for @args.kv -> $k, $v
        {
            @params[$k] = !$v.defined ?? Str !!
                (given @!paramtypes[$k]
                {
                    default { ~$v }
                });
        }

        with $!result { .clear; $!result = PGresult }

        $!row = $!rows = 0;

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
                    $!rows = $result.tuples;
                    DB::Pg::Results.new(sth => self, finishflag => $finish)
                }
                when PGRES_COMMAND_OK
                {
                    $result.clear;
                    self.finish if $finish;
                    $!db
                }
                default { ... }
            }
        }
    }
}

class DB::Pg::Database
{
    has PGconn $.conn handles<status>;
    has $.dbpg;
    has %.prepare-cache;
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

    method active { $!active = True; self }

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
        die DB::Pg::Error(message => $!conn.error-message);
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
            .map({ %oid-to-type{$result.param-type($_)} });

        my @columns = (^$result.fields).map({ $result.field-name($_) });

        my @types = (^$result.fields).
            map({ %oid-to-type{$result.field-type($_)} });

        $result.clear;

        %!prepare-cache{$query} = DB::Pg::Statement.new(:db(self), :$name,
                                                        :@paramtypes, :@columns,
                                                        :@types);
    }

    my class DB::Pg::CopyOutIterator does Iterator
    {
        has $.db;
        has $.finish;
        has $.decode;

        method pull-one
        {
            my Pointer $ptr .= new;

            given $!db.conn.get-copy-data($ptr, 0)
            {
                when * > 0  # Number of bytes returned
                {
                    LEAVE PQfreemem($ptr);
                    my $buf = Buf.new(nativecast(CArray[uint8], $ptr)[0 ..^ $_]);
                    $!decode ?? $buf.decode !! $buf;
                }
                when -1     # Complete
                {
                    $!db.finish if $!finish;
                    IterationEnd
                }
                when -2     # Error
                {
                    die DB::Pg::Error(message => $!db.conn.error-message);
                }
            }
        }
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

    method query(Str:D $query, *@args, Bool :$finish = False)
    {
        try
        {
            return self.prepare($query).execute(|@args, :$finish);

            CATCH
            {
                when DB::Pg::Error::EmptyQuery |
                     DB::Pg::Error::FatalError
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

    my class DB::Pg::CursorIterator does Iterator
    {
        has $.sth;
        has $.name;
        has $.hash;
        has $.finish;

        method pull-one
        {
            try
            {
                if $!sth.rows
                {
                    my $row = $!sth.row(:$!hash);
                    return $row if $row.elems;
                    $!sth.execute;
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
                    when DB::Pg::Error::EmptyQuery |
                         DB::Pg::Error::FatalError
                    {
                        $!sth.finish if $!finish;
                        .throw;
                    }
                }
            }
        }
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
                                                       :$hash, :$finish);

            CATCH
            {
                when DB::Pg::Error::EmptyQuery |
                     DB::Pg::Error::FatalError
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
    has @.connections;
    has $!connection-lock = Lock.new;

    has $!listen-db;
    has %!suppliers;
    has $!supplier-lock = Lock.new;

    method db(--> DB::Pg::Database)
    {
        $!connection-lock.protect:
        {
            while @!connections.elems
            {
                my $db = @!connections.pop;

                return $db.active if $db.status == CONNECTION_OK;

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

    method listen-loop
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
        self.listen-loop unless $!listen-db;
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
