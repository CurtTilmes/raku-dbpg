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

=begin pod

=head1 NAME

DB::Pg::Statement -- PostgreSQL prepared statement object

=head1 SYNOPSIS

 my $pg = DB::Pg.new;

 my $db = $pg.db;

 my $sth = $db.prepare('select * from foo where x = $1');

 my $result = $sth.execute(12);

=head1 DESCRIPTION

Holds a prepared database statement.  The only thing you can really do
with a prepared statement is to C<.execute> it with arguments to bind
to the prepared placeholders.

=head1 METHODS

=head2 B<paramtypes>()

Array of Perl types of the required parameters for the prepared
statement.

=head2 B<columns>()

Array of the names of the columns (fields) to be returned.

=head2 B<types>()

Array of the Perl types of the columns (fields) to be returned.

=head2 B<execute>(**@args, :finish, :decode)

Executes the database statement with the supplied arguments.

If the database returns tuple results (typical for a C<SELECT>
statement, this returns a C<DB::Pg::Results> object.

If a COPY command was issued, this will return a sequence of bulk copy
blocks of data.  For COPY commands only, if :decode is True, the bulk
copy data will be decoded and returned as Strs instead of Blobs
(default).

If :finish is True, the database connection will C<finish> following
the execution and retrieval of results.

=end pod
