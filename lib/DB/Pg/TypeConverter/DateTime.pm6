role DB::Pg::TypeConverter::DateTime
{
    submethod BUILD
    {
        self.add-type(date => Date,
                      _date => Array[Date],
                      timestamp => DateTime,
                      _timestamp => Array[DateTime],
                      timestamptz => DateTime,
                      _timestamptz => Array[DateTime]);
    }

    multi method convert(Date:U, Str:D $value)
    {
        Date.new($value)
    }

    multi method convert(DateTime:U, Str:D $value)
    {
        DateTime.new: $value.split(' ').join('T')
    }
}
