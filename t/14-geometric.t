use v6;

use Test;
use Test::When <extended>;

use DB::Pg;
use DB::Pg::GeometricTypes;
use DB::Pg::Converter::Geometric;

plan 7;

my $pg = DB::Pg.new;

$pg.converter does DB::Pg::Converter::Geometric;

is-deeply $pg.query(Q<select '(1,2e43)'::point>).value,
    Point.new(x => 1e0, y => 2e43), 'Point';

is-deeply $pg.query(Q<select '{1,2,3}'::line>).value,
    Line.new(a => 1e0, b => 2e0, c => 3e0), 'Line';

is-deeply $pg.query(Q<select '((1,2),(3,4))'::lseg>).value,
    LineSegment.new(p1 => Point.new(x => 1e0, y => 2e0),
                    p2 => Point.new(x => 3e0, y => 4e0)), 'LineSegment';

is-deeply $pg.query(Q<select '1,2,3,4'::box>).value,
    Box.new(c1 => Point.new(x => 3e0, y => 4e0),
            c2 => Point.new(x => 1e0, y => 2e0)), 'Box';

is-deeply $pg.query(Q<select '[(1,2),(3,4),(5,6)]'::path>).value,
    Path.new(:closed, points => (Point.new(x => 1e0, y => 2e0),
                                 Point.new(x => 3e0, y => 4e0),
                                 Point.new(x => 5e0, y => 6e0))), 'Path';

is-deeply $pg.query(Q<select '(1,2),(3,4),(5,6)'::polygon>).value,
    Polygon.new(points => (Point.new(x => 1e0, y => 2e0),
                           Point.new(x => 3e0, y => 4e0),
                           Point.new(x => 5e0, y => 6e0))), 'Polygon';

is-deeply $pg.query(Q<select '5,6,1'::circle>).value,
    Circle.new(x => 5e0, y => 6e0, r => 1e0), 'Circle';

done-testing;

