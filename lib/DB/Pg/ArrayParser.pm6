use v6;

grammar DB::Pg::ArrayParser {
    rule TOP         { ^ <array> $ }
    rule array       { '{' ~ '}' <element>+ % ',' }
    rule element     { <array> | <number> | <quoted> | <string> | <null> }
    token number     { <[+-]>? \d+ ['.' \d+]? [ <[eE]> <[+-]>?  \d+ ]? }
    token string     { \w+ }
    token quoted     { '"' ~ '"' [ <str> | \\ <str=.escaped> ]* }
    token str        { <-["\\]>+ }
    token escaped    { <["\\]> }
    token null       { NULL }
};

class DB::Pg::ArrayActions
{
    method TOP($/) { make $<array>.made }

    method array($/) { make $<element>».made }

    method element($/)
    {
        make $<array>.made // $<number>.made // $<quoted>.made //
            $<string>.made // $<null>.made
    }

    method number($/) { make $*converter.convert($*type, ~$/) }

    method string($/) { make $*converter.convert($*type, ~$/) }

    method quoted($/) { make $*converter.convert($*type, $<str>».made.join) }

    method str($/) { make ~$/ }

    method escaped($/) { make ~$/ }

    method null($/) { make $*type }
}
