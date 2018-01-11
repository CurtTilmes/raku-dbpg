#!/usr/bin/env perl6

use DB::Pg::Converter;

use LibUUID;

role UUIDConverter
{
    submethod BUILD { self.add-type(uuid => UUID) }

    multi method convert(UUID:U, $value) { UUID.new: $value }

}

my $converter = DB::Pg::Converter.new does UUIDConverter;

my $res = $converter.convert(2950, '5c64e2cf-1750-41c9-a73d-720a78029510');

dd $res;


