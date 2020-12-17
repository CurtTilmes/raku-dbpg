use LibUUID;

role DB::Pg::Converter::UUID
{
    submethod BUILD { self.add-type(uuid => UUID) }
    multi method convert(UUID:U, Mu:D $value) { UUID.new: $value }
}
