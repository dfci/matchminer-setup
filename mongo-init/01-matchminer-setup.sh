#!/usr/bin/env bash
set -euo pipefail

# mongosh creates some noisy log messages when it can't write to the user's HOME
# directory, which (for some reason) is the case in the default mongodb image.
# to get around this, we set HOME to a temporary directory when running mongosh.
TEMP_MONGOSH_DIR="$(mktemp -d)"

echo 'Initializing replica set...'
HOME="$TEMP_MONGOSH_DIR" mongosh --quiet --eval 'rs.initiate();'

echo 'Waiting for replica set initialization to complete...'
while ! HOME="$TEMP_MONGOSH_DIR" mongosh --quiet --eval 'rs.conf()'
do
  echo 'Continuing to wait...'
  sleep 0.5
done

echo 'Restoring metadata from mongo-seed...'
rm -rf /tmp/mongo-seed-meta
mkdir -p /tmp/mongo-seed-meta
cp /mongo-seed/*.metadata.json /tmp/mongo-seed-meta/
mongorestore --drop --preserveUUID --dir=/tmp/mongo-seed-meta mongodb://localhost/matchminer

echo 'Restoring collection data from mongo-seed...'
for FILE in /mongo-seed/*.items.json
do
  BASENAME="$(basename $FILE)"
  COLLNAME="${BASENAME%.items.json}"
  echo 'Restoring collection $COLLNAME...'
  mongoimport --type=json --collection=$COLLNAME mongodb://localhost/matchminer $FILE
done
