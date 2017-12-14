use DB::Pg::Native;
use DB::Pg::Results;

class DB::Pg::Statement
{
    has $.db handles <finish>;
    has $.name;
    has @.paramtypes;
    has @.columns;
    has @.types;

    method execute(**@args, Bool :$finish = False, Bool :$decode = True)
    {
        my @params := $!db.converter.convert-params(@args, @!paramtypes, :$!db);

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
                    DB::Pg::Results.new(sth => self, :$result, :$finish)
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
