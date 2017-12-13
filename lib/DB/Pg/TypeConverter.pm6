use NativeCall;
use DB::Pg::Native;
use DB::Pg::ArrayParser;

unit class DB::Pg::TypeConverter;

has %.oid-map =
    16    => 'bool',
    17    => 'bytea',
    18    => 'char',
    19    => 'name',
    20    => 'int8',
    21    => 'int2',
    23    => 'int4',
    25    => 'text',
    26    => 'oid',
    114   => 'json',
    142   => 'xml',
    143   => '_xml',
    199   => '_json',
    600   => 'point',
    601   => 'lseg',
    602   => 'path',
    603   => 'box',
    604   => 'polygon',
    628   => 'line',
    629   => '_line',
    650   => 'cidr',
    700   => 'float4',
    701   => 'float8',
    705   => 'unknown',
    718   => 'circle',
    719   => '_circle',
    790   => 'money',
    791   => '_money',
    829   => 'macaddr',
    869   => 'inet',
    1000  => '_bool',
    1001  => '_bytea',
    1002  => '_char',
    1003  => '_name',
    1005  => '_int2',
    1007  => '_int4',
    1009  => '_text',
    1014  => '_bpchar',
    1015  => '_varchar',
    1016  => '_int8',
    1017  => '_point',
    1018  => '_lseg',
    1019  => '_path',
    1020  => '_box',
    1021  => '_float4',
    1022  => '_float8',
    1027  => '_polygon',
    1028  => '_oid',
    1040  => '_macaddr',
    1041  => '_inet',
    1042  => 'bpchar',
    1043  => 'varchar',
    1082  => 'date',
    1083  => 'time',
    1114  => 'timestamp',
    1115  => '_timestamp',
    1182  => '_date',
    1183  => '_time',
    1184  => 'timestamptz',
    1185  => '_timestamptz',
    1186  => 'interval',
    1187  => '_interval',
    1231  => '_numeric',
    1266  => 'timetz',
    1270  => '_timetz',
    1560  => 'bit',
    1561  => '_bit',
    1562  => 'varbit',
    1563  => '_varbit',
    1700  => 'numeric',
    2950  => 'uuid',
    2951  => '_uuid',
    3802  => 'jsonb',
    3807  => '_jsonb',
;

has %.type-map =
    'bool'         => Bool,
    'bytea'        => Buf,
    'char'         => Str,
    'name'         => Str,
    'int8'         => Int,
    'int2'         => Int,
    'int4'         => Int,
    'text'         => Str,
    'oid'          => Int,
    'json'         => Str,
    'xml'          => Str,
    '_xml'         => Array[Str],
    '_json'        => Array[Str],
    'point'        => Str,
    'lseg'         => Str,
    'path'         => Str,
    'box'          => Str,
    'polygon'      => Str,
    'line'         => Str,
    '_line'        => Array[Str],
    'cidr'         => Str,
    'float4'       => Num,
    'float8'       => Num,
    'unknown'      => Any,
    'circle'       => Str,
    '_circle'      => Array[Str],
    'money'        => Rat,
    '_money'       => Array[Rat],
    'macaddr'      => Str,
    'inet'         => Str,
    '_bool'        => Array[Bool],
    '_bytea'       => Array[Buf],
    '_char'        => Array[Str],
    '_name'        => Array[Str],
    '_int2'        => Array[Int],
    '_int4'        => Array[Int],
    '_text'        => Array[Str],
    '_bpchar'      => Array[Str],
    '_varchar'     => Array[Str],
    '_int8'        => Array[Int],
    '_point'       => Array[Str],
    '_lseg'        => Array[Str],
    '_path'        => Array[Str],
    '_box'         => Array[Str],
    '_float4'      => Array[Num],
    '_float8'      => Array[Num],
    '_polygon'     => Array[Str],
    '_oid'         => Array[Int],
    '_macaddr'     => Array[Str],
    '_inet'        => Array[Str],
    'bpchar'       => Str,
    'varchar'      => Str,
    'date'         => Date,
    'time'         => Str,
    'timestamp'    => DateTime,
    '_timestamp'   => Array[DateTime],
    '_date'        => Array[Date],
    '_time'        => Array[Str],
    'timestamptz'  => DateTime,
    '_timestamptz' => Array[DateTime],
    'interval'     => Str,
    '_interval'    => Array[Str],
    '_numeric'     => Array[Num],
    'timetz'       => Str,
    '_timetz'      => Array[Str],
    'bit'          => Str,
    '_bit'         => Array[Str],
    'varbit'       => Str,
    '_varbit'      => Array[Str],
    'numeric'      => Num,
    'uuid'         => Str,
    '_uuid'        => Array[Str],
    'jsonb'        => Str,
    '_jsonb'       => Array[Str],
;

method add-oid(*@oid-map)
{
    for @oid-map -> Pair (:key($oid), :value($type))
    {
        %!oid-map{$oid} = $type;
        %!oid-map{"_$oid"} = Array[$type];
    }
}

method add-type(*%type-map)
{
    for %type-map.kv -> $pgtype, $perltype
    {
        %!type-map{$pgtype} = $perltype
    }
}

multi method type(Int:D $oid)
{
    die "Unknown oid $oid" unless %!oid-map{$oid}:exists;
    self.type(%!oid-map{$oid})
}

multi method type(Str:D $type)
{
    die "Uknown type $type" unless %!type-map{$type}:exists;
    %!type-map{$type}
}

multi method convert(Int:D $oid, Mu:D $value)
{
    self.convert: self.type($oid), $value
}

multi method convert(Str:D $type, Mu:D $value)
{
    self.convert: self.type($type), $value
}

multi method convert(Any:U, Mu:D $value)      { $value }

multi method convert(Bool:U, Mu:D $value)     { $value eq 't' }

multi method convert(Int:U, Mu:D $value)      { $value.Int }

multi method convert(Num:U, Mu:D $value)      { $value.Num }

multi method convert(Date:U, Mu:D $value)     { Date.new($value) }

multi method convert(DateTime:U, Mu:D $value)
{
    DateTime.new: $value.split(' ').join('T')
}

multi method convert(Buf:U, Mu:D $value)
{
    my size_t $bytes;
    my $ptr = PQunescapeBytea($value, $bytes) // die "Out of Memory";
    LEAVE PQfreemem($_) with $ptr;
    Buf.new(nativecast(CArray[uint8], $ptr)[0 ..^ $bytes])
}

multi method convert(Array:U $type, Mu:D $value)
{
    my $*converter = self;
    my $*type = $type.of;

    DB::Pg::ArrayParser.parse($value, actions => DB::Pg::ArrayActions)
        // die "Failed to parse array";
    $/.made
}

multi method convert(Mu:D $value, Mu:U)
{
    ~$value
}

multi method convert(Blob:D $value, Buf:U)
{
    $*db.conn.escape-bytea($value)
}

multi method convert(@value, Array:U $type)
{
    '{' ~
        @value.map(
            {
                when Array   { self.convert($_,$type) }
                when Numeric { $_ }
                default
                {
                    '"' ~
                        .subst(/\"/, '\\"', :g)
                        .subst(/\\/, Q<\\>, :g)
                    ~ '"'
                }
            }).join(',')
    ~ '}'
}

method convert-params(@args, @paramtypes, :$db)
{
    my $*db = $db;

    my @params := CArray[Str].new;

    for @args.kv -> $k, $v
    {
        @params[$k] = !$v.defined ?? Str !! self.convert($v, @paramtypes[$k])
    }

    @params
}
