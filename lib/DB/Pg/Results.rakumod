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

    method DESTROY { self.clear }

    method clear
    {
        .clear with $!result;
        $!result = PGresult;
    }

    method finish
    {
        self.clear;
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

    method col-array(Int $col = 0)
    {
        LEAVE $.finish if $!finish;
        (^$.rows).map({ $.row($_)[$col] }).Array
    }
}

=begin pod

=head1 NAME

DB::Pg::Results -- Results from a PostgreSQL query

=head1 SYNOPSIS

 my $results = $sth.execute(1);

 say $results.rows;     # Number of rows returned

 say $results.columns;  # Array of column (field) names

 say $results.types;    # Array of column Perl types

 say $results.value;    # A single scalar value

 say $results.array;    # A single array with one row

 say $results.hash;     # A single hash with one row

 say $results.arrays;   # A sequence of arrays with all rows

 say $results.hashes;   # A sequence of hashes with all rows

 say $results.col-array;    # A single array of one column.

 $results.finish        # Only needed if results aren't consumed.

=head1 DESCRIPTION

Returned from a C<DB::Pg::Statement> execution that returns results.

=head1 METHODS

=head2 B<rows>()

Returns number of rows returned.

=head2 B<columns>()

Array of the names of the columns (fields) to be returned.

=head2 B<types>()

Array of the Perl types of the columns (fields) to be returned.

=head2 B<finish>()

Finish with the database connection.  This is only needed if the complete
database returns aren't consumed.

=head2 B<row>(Int $row, Bool :hash)

Retrieves a specific row from the results, either as an array, or as a
Hash if :hash is True.

=head2 B<value>()

Return a single scalar value from the results.

=head2 B<array>()

Return a single row from the results as an array.

=head2 B<hash>()

Return a single row from the results as a hash.

=head2 B<arrays>()

Returns a sequence of all rows as arrays.

=head2 B<hashes>()

Returns a sequence of all rows as hashes.

=head2 B<col-array>(Int $col = 0)

Retrieves a specific column from the results as an array.

=end pod
