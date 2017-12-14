use JSON::Fast;

my class JSON {}

role DB::Pg::TypeConverter::JSON
{
    submethod BUILD { self.add-type(json => JSON, jsonb => JSON) }

    multi method convert(JSON:U, Mu:D $value) { from-json($value) }

    multi method convert(Mu:D $value, JSON:U) { to-json($value) }
}
