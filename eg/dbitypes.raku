#!/usr/bin/env perl6

use DBIish;

my $db = DBIish.connect('Pg');

my $sth = $db.prepare('select * from foo');

$sth.execute;

dd $sth.allrows;
