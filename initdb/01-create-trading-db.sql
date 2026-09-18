CREATE DATABASE trading_db;
CREATE DATABASE finvasia;
CREATE DATABASE mano_trading_db;
CREATE DATABASE kotak_neo;
CREATE DATABASE angel_one;

-- postgres.conf already loads pg_stat_statements via shared_preload_libraries, but that only
-- reserves the shared-memory tracking - the module's actual stats VIEW is inaccessible in a
-- database until CREATE EXTENSION runs in THAT database specifically. Without this, the tuning
-- this config was clearly set up for isn't usable in any database. \connect (a psql meta-command,
-- valid here since docker's postgres image runs these init scripts through psql, not a raw
-- driver) switches into each one so the extension actually lands where it's needed.
-- NOTE: /docker-entrypoint-initdb.d scripts only run against a brand-new, empty data directory -
-- this won't retroactively apply to an already-initialized volume. Run
-- `CREATE EXTENSION IF NOT EXISTS pg_stat_statements;` by hand in each existing database if you
-- want this on the currently-running instance.
\connect algo
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
\connect trading_db
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
\connect finvasia
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
\connect mano_trading_db
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
\connect kotak_neo
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
\connect angel_one
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;