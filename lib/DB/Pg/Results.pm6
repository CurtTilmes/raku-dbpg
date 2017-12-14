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
