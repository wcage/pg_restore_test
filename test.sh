#!/bin/bash

database="poc_bytea_db"
seq="general_sequence"
batchCount=200
batchSize=100
filename=dump_$(date +%m-%d-%y_%H%M%S).sql
export PGPASSWORD="servicehouse"

random_bytea_func="CREATE OR REPLACE FUNCTION random_bytea(bytea_length integer)
    RETURNS bytea AS \$body$
SELECT decode(string_agg(lpad(to_hex(width_bucket(random(), 0, 1, 256)-1),2,'0') ,''), 'hex')
FROM generate_series(1, \$1);
\$body$
    LANGUAGE 'sql'
    VOLATILE
    SET search_path = 'pg_catalog';
    ";

function recreate_db () {
  echo "(Re-)creating database"
  psql -h localhost -d postgres servicehouse -c "drop database if exists $database;"
  psql -h localhost -d postgres servicehouse -c "create database $database;"
}

recreate_db

echo "Initializing database"
psql -h localhost -d $database servicehouse -c "create table poc_with_bytea (id bigint not null constraint bytea_seq primary key, blob_bytea bytea);"
psql -h localhost -d $database servicehouse -c "$random_bytea_func"
psql -h localhost -d $database servicehouse -c "create sequence $seq"

echo "Inserting $batchCount batches with $batchSize (total: $((batchCount*batchSize))) records"

for ((j=1; j<=$batchCount; j++))
do
  query="insert into poc_with_bytea (id, blob_bytea) values (nextval('$seq'), random_bytea(10000)) "
  for ((i=1; i<=$batchSize-1; i++))
  do
    query+=", (nextval('$seq'), random_bytea(35000))"
  done
  psql -h localhost -d $database servicehouse -c "$query;"
done

echo "Current amount of bytea records:"
psql -h localhost -d $database servicehouse -c "select count(*) from poc_with_bytea"

echo "Dumping to $filename"

time pg_dump -h localhost -U servicehouse $database -F t > "$filename"

echo "Done dumping $(date +%m-%d-%y_%H%M%S)"
ls -lah | grep "$filename"

recreate_db

echo "Restoring ... from $filename"
time pg_restore -h localhost -U servicehouse -d $database -v "$filename"

#echo "Removing $filename"
#rm "$filename"
#ls -lah | grep "$filename"