use DB::Pg::GeometricTypes;

my regex float { <[+-]>? \d+ ['.' \d+]? [ <[eE]> <[+-]>?  \d+ ]? }
my regex point { '(' <x=float> ',' <y=float> ')' }

role DB::Pg::TypeConverter::Geometric
{
    submethod BUILD
    {
        self.add-type(
            point   => Point,
            line    => Line,
            lseg    => LineSegment,
            box     => Box,
            path    => Path,
            polygon => Polygon,
            circle  => Circle,
        );
    }

    multi method convert(Point:U, Str:D $value)
    {
        $value ~~ /^ <point> $/
            ?? Point.new(x => $<point><x>.Num, y => $<point><y>.Num)
            !! Point;
    }

    multi method convert(Line:U, Str:D $value)
    {
        $value ~~ /^ '{' <a=float> ',' <b=float> ',' <c=float> '}' $/
            ?? Line.new(a => $<a>.Num, b => $<b>.Num, c => $<c>.Num)
            !! Line;
    }

    multi method convert(LineSegment:U, Str:D $value)
    {
        $value ~~ /^ '[' <p1=point> ',' <p2=point> ']' $/
            ?? LineSegment.new(p1 => Point.new(x => $<p1><x>.Num,
                                               y => $<p1><y>.Num),
                               p2 => Point.new(x => $<p2><x>.Num,
                                               y => $<p2><y>.Num))
            !! LineSegment;
    }

    multi method convert(Box:U, Str:D $value)
    {
        $value ~~ /^ <c1=point> ',' <c2=point> $/
            ?? Box.new(c1 => Point.new(x => $<c1><x>.Num,
                                       y => $<c1><y>.Num),
                       c2 => Point.new(x => $<c2><x>.Num,
                                       y => $<c2><y>.Num))
            !! Box;
    }

    multi method convert(Path:U, Str:D $value)
    {
        $value ~~ /^ ('[' | '(') <point>+ % ',' (']' | ')')  $/
        ?? Path.new(closed => $0 eq '[',
                    points => do for $<point> -> $p
                    { Point.new(x => $p<x>.Num, y => $p<y>.Num) } )
        !! Path;

    }

    multi method convert(Polygon:U, Str:D $value)
    {
        $value ~~ /^ '(' <point>+ % ',' ')' $/
            ?? Polygon.new(points => do for $<point> -> $p
                           { Point.new(x => $p<x>.Num, y => $p<y>.Num) } )
            !! Polygon;
    }

    multi method convert(Circle:U, Str:D $value)
    {
        $value ~~ /^ '<' <point> ',' <r=float> '>' $/
            ?? Circle.new(x => $<point><x>.Num,
                          y => $<point><y>.Num,
                          r => $<r>.Num)
            !! Circle;
    }
}
