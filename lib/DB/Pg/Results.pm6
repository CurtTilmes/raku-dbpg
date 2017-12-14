use DB::Pg::Native;

class DB::Pg::ArrayIterator does Iterator
{
    has $.res;
    has Bool $.finish;
    has Bool $.hash;
    has Int $.rows;
    has Int $!row = 0;

    method pull-one
    {
        if $!row == $!rows
        {
            $!res.finish if $!finish;
            return IterationEnd
        }
        $!res.row($!row++, :$!hash)
    }
}

class DB::Pg::Results
{
    has Bool $.finish = False;
    has $.sth handles <columns types>;
    has PGresult $.result;

    method DESTROY { .clear with $!result }

    method finish
    {
        .clear with $!result;
        $!result = PGresult;
        $!sth.finish
    }

    method rows { $!result.tuples }

    method row(Int $row, Bool :$hash)
    {
        return () unless 0 ≤ $row < self.rows;

        my @row = do for ^$!sth.columns.elems Z $!sth.types -> [$col, $type]
        {
            $!result.getisnull($row, $col)
                ?? $type
                !! $!sth.db.converter.convert($type,
                                              $!result.getvalue($row, $col))
        }

        $hash ?? %($!sth.columns Z=> @row) !! @row
    }

    method value
    {
        LEAVE self.finish if $!finish;
        self.row(0)[0]
    }

    method array
    {
        LEAVE self.finish if $!finish;
        self.row(0)
    }

    method hash
    {
        LEAVE self.finish if $!finish;
        self.row(0, :hash) or Nil
    }

    method arrays
    {
        Seq.new: DB::Pg::ArrayIterator.new(res => self, :$!finish, :!hash,
                                           rows => self.rows)
    }

    method hashes
    {
        Seq.new: DB::Pg::ArrayIterator.new(res => self, :$!finish, :hash,
                                           rows => self.rows)
    }
}
