#!/usr/bin/env raku

use DBIish;

my $db = DBIish.connect('Pg');

my $sth = $db.prepare('select * from foo');

$sth.execute;

dd $sth.allrows;
