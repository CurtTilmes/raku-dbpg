class Point
{
    has Num $.x;
    has Num $.y;

    method Str { "( $!x, $!y )" }
}

class Line
{
    has Num $.a;
    has Num $.b;
    has Num $.c;

    method Str { "{ $!a, $!b, $!c }" }
}

class LineSegment
{
    has Point $.p1;
    has Point $.p2;

    method Str { "[ $!p1, $!p2 ]" }
}

class Box
{
    has Point $.c1;
    has Point $.c2;

    method Str { "$!c1, $!c2" }
}

class Path
{
    has Bool $.closed;
    has @.points;

    method Str { ($!closed ?? '[' !! '(')
                 ~ join(',', (.Str for @!points))
                 ~ ($!closed ?? ']' !! ')') }
}

class Polygon
{
    has @.points;

    method Str { '(' ~ join(',', (.Str for @!points)) ~ ')' }
}

class Circle
{
    has Num $.x;
    has Num $.y;
    has Num $.r;

    method Str { "<($!x, $!y), $!r>" }
}
