grammar DB::Pg::ArrayParser
{
    rule TOP         { ^ <array> $ }

    rule array       { '{' ~ '}' <element>* % ',' }

    rule element     { <array> | <string> | <quoted> | <null> }

    token string     { <-[",{}\ ]>+ }

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
        make $<array>.made // $<string>.made // $<quoted>.made // $<null>.made
    }

    method string($/) { make $*converter.convert($*type, ~$/) }

    method quoted($/) { make $*converter.convert($*type, $<str>».made.join) }

    method str($/) { make ~$/ }

    method escaped($/) { make ~$/ }

    method null($/) { make $*type }
}
