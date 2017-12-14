use epoll;

use DB::Pg::Native;
use DB::Pg::Database;
use DB::Pg::TypeConverter;
use DB::Pg::TypeConverter::DateTime;
use DB::Pg::TypeConverter::Geometric;
use DB::Pg::TypeConverter::JSON;
use DB::Pg::TypeConverter::UUID;

class DB::Pg
{
    has $.conninfo = '';
    has @.converters = <DateTime JSON UUID Geometric>;

    has DB::Pg::TypeConverter $.converter .= new;

    has @.connections;
    has $!connection-lock = Lock.new;

    has $!listen-db;
    has $!listen-db-lock = Lock.new;
    has %!suppliers;
    has $!supplier-lock = Lock.new;

    submethod TWEAK
    {
        $!converter does DB::Pg::TypeConverter::{$_} for @!converters;
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

    method !listen-loop
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
