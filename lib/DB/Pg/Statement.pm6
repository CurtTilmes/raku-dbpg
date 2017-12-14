use DB::Pg::Native;
use DB::Pg::Results;

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
