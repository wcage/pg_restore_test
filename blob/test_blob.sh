#!/bin/bash

#Example usage: ./test_blob.sh &> results/blob_$(date +%m-%d-%y_%H%M%S)_output.txt

database="poc_blob_db"
table="poc_with_blob"
seq="blob_sequence"
blobCount=1000
fileSizeBytes=10000
timestamp=$(date +%m-%d-%y_%H%M%S)

filename=dump_$timestamp.sql
export PGPASSWORD="servicehouse"

echo "results with blobCount=$blobCount and fileSizeBytes=$fileSizeBytes at $timestamp"

function recreate_db () {
  echo "(Re-)creating database"
  psql -h localhost -d postgres servicehouse -c "drop database if exists $database;"
  psql -h localhost -d postgres servicehouse -c "create database $database;"
}

recreate_db

echo "Initializing database"
psql -h localhost -d $database servicehouse -c "create table $table (id bigint not null primary key, pdfbloboid oid);"
psql -h localhost -d $database servicehouse -c "create sequence $seq"

echo "Inserting $blobCount blob records"

for ((j=1; j<=$blobCount; j++))
do
  dummyfilename="dummy/dummy_$(shuf -i 1-100000 -n 1).pdf"
  head -c $fileSizeBytes /dev/urandom > $dummyfilename
  oid=$(psql -h localhost -d $database servicehouse -c "\lo_import '/home/wouter/dev/pg_restore_test/blob/$dummyfilename'"  | cut -d " " -f 2)
  psql -h localhost -d $database servicehouse -c "insert into $table values (nextval('$seq'), $oid) "
done

echo "Current amount of blob records:"
psql -h localhost -d $database servicehouse -c "select count(*) from $table"

echo "removing all dummy files ..."
rm /home/wouter/dev/pg_restore_test/blob/dummy/*

echo "Dumping to $filename"
time pg_dump -h localhost -U servicehouse $database -F t > "$filename"

echo "Done dumping $(date +%m-%d-%y_%H%M%S)"
ls -lah | grep "$filename"

recreate_db

echo "Restoring from $filename"
time pg_restore -h localhost -U servicehouse -d $database -v "$filename"

#echo "Removing $filename"
#rm "$filename"
#ls -lah | grep "$filename"
