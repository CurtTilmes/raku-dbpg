use DB::Pg::Native;
use DB::Pg::Database;
use DB::Pg::Converter;
use DB::Pg::Converter::DateTime;
use DB::Pg::Converter::Geometric;
use DB::Pg::Converter::JSON;
use DB::Pg::Converter::UUID;

try require ::('epoll');

class DB::Pg
{
    has $.conninfo = '';
    has $.max-connections = 5;
    has @.converters = <DateTime JSON UUID Geometric>;
    has DB::Pg::Converter $.converter .= new;

    has @.connections;
    has $!connection-lock = Lock.new;

    has $!listen-db;
    has $!listen-db-lock = Lock.new;
    has %!suppliers;
    has $!supplier-lock = Lock.new;

    submethod TWEAK
    {
        $!converter does DB::Pg::Converter::{$_} for @!converters;
    }

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
        $!connection-lock.protect:
        {
            if @!connections.elems < $!max-connections
            {
                @!connections.push($db)
            }
            else
            {
                $db.DESTROY
            }
        }
    }

    method query(|args)
    {
        self.db.query(|args, :finish)
    }

    method execute(Str:D $command)
    {
        self.db.execute($command, :finish)
    }

    method cursor(|args)
    {
        self.db.cursor(|args, :finish)
    }

    method notify(Str:D $channel, Str:D $message)
    {
        self.db.notify($channel, $message, :finish)
    }

    method !listen-loop
    {
        $!listen-db = self.db;
        my $epoll = ::('epoll').new.add($!listen-db.conn.socket, :in);
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
        die "Must install epoll to use listen()" if ::('epoll') ~~ Failure;
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

=begin pod

=head1 NAME

DB::Pg -- PostgreSQL access for Perl 6

=head1 SYNOPSIS

 my $pg = DB::Pg.new;  # You can pass in connection information if you want.

 say $pg.query('select 42').value;
 # 42

 # No arguments or return
 $pg.execute('insert into foo (x,y) values (1,2)');

 for $pg.query('select * from foo').arrays -> @row {
     say @row;
 }

 for $pg.query('select * from foo').hashes -> %row {
     say %row;
 }

=head1 DESCRIPTION

The main C<DB::Pg> object.  It manages a pool of database connections
(C<DB::Pg::Database>), creating new ones as needed, and caching idle
ones.

It has a number of methods that simply allocate a database connection,
call the same method on that connection, then immediately return the
connection to the pool.

=head1 METHODS

=head2 B<new>(:conninfo, :max-connections, :converters)

=begin item
B<:conninfo> is any valid L<PostgreSQL connection
 string|https://www.postgresql.org/docs/10/static/libpq-connect.html#LIBPQ-CONNSTRING>.

Usually something like this:

 'postgresql:///mydb?host=localhost&port=5433'

or this:

 'host=localhost port=5432 dbname=mydb connect_timeout=10'

or, if you put the connection info in .pg_service.conf (you should)

 'service=foo'

=end item

=begin item
B<:max-connections> - Number of spare database connections to keep cached in the pool before closing them.
=end item

=begin item
B<:converters> - Array of strings specifying Type Converters to use.

Defaults to C<DateTime, JSON, UUID, Geometric>.
=end item

=head2 B<db>()

Allocate a C<DB::Pg::Database> object, either using a cached one from
the pool of idle connections, or creating a new one.

=head2 B<query>(Str:D $sql, *@args)

Allocates a database connection, performs the query with the specified
arguments, then returns the database to the pool.

If the query returns results, retuns a C<DB::Pg::Results> object with
the results.

=head2 B<execute>(Str:D $sql)

Allocates a database connection, executes the SQL statement, then
returns the database to the pool.

=head2 B<cursor>(Str:D $sql, *@args, Bool :hash, Int :fetch)

Allocates a database connections, creates and returns the cursor
sequence.  B<:fetch> defaults to 1000 rows per database fetch.
B<:hash> returns hashes for rows instead of arrays.

=head2 B<listen>(Str:D $channel)

Issues a PostgreSQL LISTEN command for the specified channel,
returning a Supply that will asynchronously return notifications.  If
you call this multiple times for the same channel, you will get the
same supply, and all listeners will get the same messages.

=head2 B<unlisten>(Str:D $channel)

Stops listening on the specified channel, and executes C<done> on the
Supply.

=head2 B<notify>(Str:D $channel, Str:D $message)

Issues a PostgreSQL NOTIFY on the specified channel.

=end pod
