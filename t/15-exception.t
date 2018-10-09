use Test;
use Test::When <extended>;

use DB::Pg;

plan 3;

my $pg = DB::Pg . new;

throws-like {
    $pg.query(q{DO LANGUAGE plpgsql $$BEGIN RAISE EXCEPTION 'Fake serialization failure' USING ERRCODE = '40001'; END;$$;});
}, DB::Pg::Error::FatalError, 'Raise Exception',
    message => 'Fake serialization failure',
    context => 'PL/pgSQL function inline_code_block line 1 at RAISE',
    state   => '40001',
    type    => 'ERROR',
    type-localized => /^ .+ $/,
    source-file => 'pl_exec.c',
    source-line => / \d+ /,
    source-function => 'exec_stmt_raise';

throws-like {
    $pg.query(q{SELECT nocolumn FROM pg_class;});
}, DB::Pg::Error::FatalError, 'Incorrect column',
    message => q{column "nocolumn" does not exist},
    state   => '42703',
    type    => 'ERROR',
    type-localized => /^ .+ $/,
    source-file   => 'parse_relation.c',
    source-line   => / \d+ /,
    source-function => 'errorMissingColumn';


throws-like {
    my $query = q:to/_QUERY_/;
      DO LANGUAGE plpgsql $$
        BEGIN RAISE EXCEPTION 'Field Test' USING
                ERRCODE = 'ERR99', DETAIL = 'Detail', HINT = 'Hint',
                COLUMN = 'Column', CONSTRAINT = 'Constraint', DATATYPE = 'Datatype',
                TABLE = 'Table', SCHEMA = 'Schema';
        END;$$;
      _QUERY_

    $pg.query($query);
}, DB::Pg::Error::FatalError, 'Raise Exception',
    message => 'Field Test',
    message-detail => 'Detail',
    message-hint => 'Hint',
    context => 'PL/pgSQL function inline_code_block line 2 at RAISE',
    state   => 'ERR99',
    type    => 'ERROR',
    schema => 'Schema',
    table => 'Table',
    column => 'Column',
    datatype => 'Datatype',
    constraint => 'Constraint',
    type-localized => /^ .+ $/,
    source-file => 'pl_exec.c',
    source-line => / \d+ /,
    source-function => 'exec_stmt_raise';

done-testing;
