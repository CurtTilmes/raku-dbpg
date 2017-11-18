use NativeCall;

my atomicint $counter = 0;

constant LIB = 'pq';  # libpq.so

enum ConnStatusType <
    CONNECTION_OK
    CONNECTION_BAD
    CONNECTION_STARTED
    CONNECTION_MADE
    CONNECTION_AWAITING_RESPONSE
    CONNECTION_AUTH_OK
    CONNECTION_SETENV
    CONNECTION_SSL_STARTUP
    CONNECTION_NEEDED
>;

enum PGTransactionStatusType <
    PQTRANS_IDLE
    PQTRANS_ACTIVE
    PQTRANS_INTRANS
    PQTRANS_INERROR
    PQTRANS_UNKNOWN
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

    method PQtransactionStatus(--> int32)
    is native(LIB) {}

    method transaction-status(--> PGTransactionStatusType)
        { PGTransactionStatusType(self.PQtransactionStatus) }

    method error-message(--> Str)
        is native(LIB) is symbol('PQerrorMessage') {}

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

    method escape-literal(Str $str, size_t $length --> Str)
        is native(LIB) is symbol('PQescapeLiteral') {}

    method escape-identifier(Str $str, size_t $length --> Str)
        is native(LIB) is symbol('PQescapeIdentifier') {}

}

class DB::Pg::Results
{
    has $.db;
    has $.sth;

    method value
    {
        LEAVE .finish with $!db;
        $!sth.row()[0]
    }

    method array
    {
        LEAVE .finish with $!db;
        $!sth.row
    }

    method hash
    {
        LEAVE .finish with $!db;
        $!sth.row(:hash)
    }

    method arrays
    {
        Seq.new(Rakudo::Iterator.FirstNThenSinkAll(
                    $!sth.iterator, $!sth.rows,
                    { .finish with $!db }))
    }

    method hashes
    {
        Seq.new(Rakudo::Iterator.FirstNThenSinkAll(
                    $!sth.iterator(:hash), $!sth.rows,
                    { .finish with $!db }))
    }
}

class DB::Pg::Iterator does Iterator
{
    has $.sth;
    has $.hash;

    method pull-one { $!sth.row(:$!hash) }

    method sink-all {}
}

class DB::Pg::Statement
{
    has $.db;
    has $.name;
    has @.paramtypes;
    has @.columns;
    has @.types;
    has PGresult $.result;
    has Int $.row;
    has Int $.rows;

    method iterator(Bool :$hash)
    {
        DB::Pg::Iterator.new(sth => self, :$hash)
    }

    method row(Bool :$hash)
    {
        return () unless $!row < $!rows;

        LEAVE $!row++;

        my @row = do for ^@!columns.elems Z @!types -> [$col, $type]
        {
            $!result.getisnull($!row, $col)
                ?? $type
                !! $!result.getvalue($!row, $col)
        }

        $hash ?? %(@!columns Z=> @row) !! @row
    }

    method execute(*@args, Bool :$finish)
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

        $!rows = 0;
        $!row = 0;
        my $result = $!db.conn.exec-prepared($!name, @params.elems, @params,
                                             Nil, Nil, 0);

        say "$!db.conn.socket() $result.status()";

        given $result.status
        {
            when PGRES_EMPTY_QUERY {
                $result.clear;
                fail "Empty Query";
            }
            when PGRES_TUPLES_OK {
                $!result = $result;
                $!rows = $result.tuples;
                DB::Pg::Results.new(sth => self, db => $finish ?? $!db !! Nil);
            }
            when PGRES_COMMAND_OK {
                $result.clear;
                self.finish if $finish;
            }
            when PGRES_FATAL_ERROR {
                fail $!db.conn.error-message;
            }
            default { ... }
        }
    }
}

class DB::Pg::Database
{
    has PGconn $.conn;
    has $.dbpg;
    has %.prepare-cache;
    has $.prepare-lock = Lock.new;

    method finish
    {
        say "$*THREAD.id() database finished $!conn.socket()";
        $!dbpg.return(self);
    }

    method prepare(Str $query --> DB::Pg::Statement)
    {
        return $_ with %!prepare-cache{$!conn.socket}{$query};

        my $name = "pg-$!conn.socket()-{$counter⚛++}";

        my $result = $!conn.prepare($name, $query, 0, Nil);

        unless $result && $result.status == PGRES_COMMAND_OK
        {
            .clear with $result;
            die $!conn.error-message;
        }

        $result = $!conn.describe-prepared($name);

        unless $result && $result.status == PGRES_COMMAND_OK
        {
            .clear with $result;
            die $!conn.error-message;
        }

        my @paramtypes = (^$result.params)
            .map({ %oid-to-type{$result.param-type($_)} });

        my @columns = (^$result.fields).map({ $result.field-name($_) });

        my @types = (^$result.fields).
            map({ %oid-to-type{$result.field-type($_)} });

        my $prepared = DB::Pg::Statement.new(:db(self), :$name,
                                             :@paramtypes, :@columns,
                                             :@types);

        $!prepare-lock.protect: {
            %!prepare-cache{$!conn.socket}{$query} = $prepared;
        }
    }

    method do(Str $query, *@args, :$finish)
    {
        self.prepare($query).execute(|@args, :$finish);
    }

    method async(Str $query, *@args)
    {
        
    }
}

class DB::Pg
{
    has $.conninfo = '';
    has @.connections;
    has $.lock = Lock.new;

    method db(--> DB::Pg::Database)
    {
        my ($db, $conn);

        $!lock.protect: { $db = @!connections.pop if @!connections.elems }

        return $_ with $db;

        loop
        {
            say "$*THREAD.id() Making new database connection";
            $conn = PGconn.new($!conninfo);
            last if $conn;
            note $conn.error-message;
            sleep 2;
        }

        say "$*THREAD.id() Made connection $conn.socket()";

        DB::Pg::Database.new(conn => $conn, dbpg => self)
    }

    method return(DB::Pg::Database:D $db)
    {
        say "$*THREAD.id() returning $db.conn.socket()";
        $!lock.protect: { @!connections.push($db) }
    }

    method do(Str $query, *@args)
    {
        self.db.prepare($query).execute(|@args, :finish);
    }
}
