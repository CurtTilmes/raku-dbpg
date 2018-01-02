use NativeCall;

constant LIBPQ = 'pq';  # libpq.so

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

class DB::Pg::Error is Exception
{
    has $.message;
}

class DB::Pg::Error::EmptyQuery    is DB::Pg::Error {}
class DB::Pg::Error::BadResponse   is DB::Pg::Error {}
class DB::Pg::Error::BadConnection is DB::Pg::Error {}
class DB::Pg::Error::FatalError    is DB::Pg::Error {}    # Not really Fatal..

sub PQlibVersion(-->uint32) is native(LIBPQ) is export {}
sub PQfreemem(Pointer) is native(LIBPQ) is export {}
sub PQunescapeBytea(Str $from, size_t $to_length is rw --> Pointer)
    is native(LIBPQ) is export {}

class PGresult is repr('CPointer')
{
    method PQresultStatus(--> int32)
        is native(LIBPQ) {}

    method status(--> ExecStatusType) { ExecStatusType(self.PQresultStatus) }

    method error-message(--> Str) is native(LIBPQ)
        is symbol('PQresultErrorMessage') {}

    method clear() is native(LIBPQ)
        is symbol('PQclear') {}

    method tuples(--> int32)
        is native(LIBPQ) is symbol('PQntuples') {}

    method fields(--> int32)
        is native(LIBPQ) is symbol('PQnfields') {}

    method field-name(int32 $column_number --> Str)
        is native(LIBPQ) is symbol('PQfname') {}

    method field-type(int32 $column_number --> uint32)
        is native(LIBPQ) is symbol('PQftype') {}

    method getvalue(int32 $row_number, int32 $column_number --> Str)
        is native(LIBPQ) is symbol('PQgetvalue') {}

    method getisnull(int32 $row_number, int32 $column_number --> int32)
        is native(LIBPQ) is symbol('PQgetisnull') {}

    method getlength(int32 $row_number, int32 $column_number --> int32)
        is native(LIBPQ) is symbol('PQgetlength') {}

    method params(--> int32)
        is native(LIBPQ) is symbol('PQnparams') {}

    method param-type(int32 $param_number--> uint32)
        is native(LIBPQ) is symbol('PQparamtype') {}

    method format(int32 $column_number --> int32)
        is native(LIBPQ) is symbol('PQfformat') {}
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
        is native(LIBPQ) {}

    method new(Str $conninfo = '') { PQconnectdb($conninfo ) }

    method finish()
        is native(LIBPQ) is symbol('PQfinish') {}

    method PQstatus(--> int32)
        is native(LIBPQ) {}

    method status(--> ConnStatusType) { ConnStatusType(self.PQstatus) }

    method error-message(--> Str)
        is native(LIBPQ) is symbol('PQerrorMessage') {}

    method PQescapeByteaConn(Blob $from, size_t $from_length,
                             size_t $to_length is rw --> Pointer)
        is native(LIBPQ) {}

    method escape-bytea(Blob:D $buf)
    {
        my size_t $bytes;
        my $ptr = self.PQescapeByteaConn($buf, $buf.bytes, $bytes)
                  // die "Out of Memory";
        LEAVE PQfreemem($_) with $ptr;
        nativecast(Str, $ptr)
    }

    method get-result(--> PGresult)
        is native(LIBPQ) is symbol('PQgetResult') {}

    method socket(--> int32)
        is native(LIBPQ) is symbol('PQsocket') {}

    method prepare(Str $stmtName,Str $query,int32 $nParams,
                   CArray[uint32] $paramTypes --> PGresult)
        is native(LIBPQ) is symbol('PQprepare') {}

    method describe-prepared(Str $stmtName --> PGresult)
        is native(LIBPQ) is symbol('PQdescribePrepared') {}

    method exec(Str $command --> PGresult)
        is native(LIBPQ) is symbol('PQexec') {}

    method exec-prepared(Str $stmtName, int32 $nParams,
                         CArray[Str] $paramValues,
                         CArray[int32] $paramLengths,
                         CArray[int32] $paramFormats,
                         int32 $resultFormat --> PGresult)
        is native(LIBPQ) is symbol('PQexecPrepared') {}

    method get-copy-data(Pointer $ptr is rw, int32 $async --> int32)
        is native(LIBPQ) is symbol('PQgetCopyData') {}

    method put-copy-data(Blob $blob, int32 $nbytes --> int32)
        is native(LIBPQ) is symbol('PQputCopyData') {}

    method put-copy-end(Str $errormsg --> int32)
        is native(LIBPQ) is symbol('PQputCopyEnd') {}

    method consume-input(--> int32)
        is native(LIBPQ) is symbol('PQconsumeInput') {}

    method PQescapeIdentifier(Blob $blob, size_t $length --> Pointer)
        is native(LIBPQ) is symbol('PQescapeIdentifier') {}

    method PQescapeLiteral(Blob $blob, size_t $length --> Pointer)
        is native(LIBPQ) is symbol('PQescapeLiteral') {}

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
        is native(LIBPQ) {}

    sub fopen(Str $path, Str $mode --> Pointer)
        is native {}

    method trace(Str $path) { self.PQtrace(fopen($path, 'a')) }

    method untrace()
        is native(LIBPQ) is symbol('PQuntrace') {}

    method notifies(--> PGnotify)
        is native(LIBPQ) is symbol('PQnotifies') {}
}

class DB::Pg::CopyOutIterator does Iterator
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
                my $buf = Buf.new(nativecast(CArray[uint8], $ptr)[^$_]);
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

=begin pod

=head1 NAME

DB::Pg::Native -- NativeCall interactions with libpq

=head1 SYNOPSIS

  my $pgconn = PGconn.new($conninfo);

  say $pgconn.status; # CONNECTION_OK or CONNECTION_BAD

  say $pgconn.error-message;

  $pgconn.finish;

=head1 DESCRIPTION

See the PostgreSQL docs:
https://www.postgresql.org/docs/current/static/libpq.html

=head2 PGconn

=head2 PGresult

=head2 PGnotify

=end pod
