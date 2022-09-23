#!/usr/bin/env bash
set -euo pipefail

echo "Setting up docker network..."
docker network create mm_custom_network
sleep 1

echo "Setting up mongo db..."
docker run -d --name mongo \
              --network=mm_custom_network \
              mongo:3.6.14 mongod --smallfiles --replSet=rs0
sleep 3

echo "Initializing mongodb as replica set..."
docker exec mongo mongo matchminer --eval "rs.initiate();"
sleep 3

echo "Setting up elasticsearch..."
docker pull matchminer/mmelastic:latest
docker run -d --name=mm_elastic \
              --network=mm_custom_network \
              matchminer/mmelastic:latest
sleep 5

echo "Setting up api..."
docker pull matchminer/mm_api:latest
docker run -d --name=mm_api \
              --network=mm_custom_network \
              --env=SECRETS_JSON=/var/www/apache-flask/api/SECRETS_JSON.json \
              --env=MONGO_URI=mongodb://mongo:27017/matchminer \
              matchminer/mm_api:latest python pymm_run.py serve --no-auth

echo "Setting up mongo-connector..."
docker pull matchminer/mm_connector:latest
docker run -d --name=mm_connector \
              --network=mm_custom_network \
              --env MONGO_URI=mongodb://mongo:27017/matchminer \
              --env ELASTICSEARCH=mm_elastic \
              --env ELASTIC_INDEX=matchminer.trial \
              matchminer/mm_connector:latest

echo "Setting up UI..."
docker pull matchminer/mm_ui:demo
docker run -d --name=mm_ui \
              --network=mm_custom_network \
              matchminer/mm_ui:latest

echo "Setting up nginx..."
docker pull matchminer/mm_nginx:latest
docker run -d --network=mm_custom_network \
              --name=nginx \
              -p 80:8881 matchminer/mm_nginx

echo "Loading demo data..."
curl -fsSL -o matchminer.tar.gz https://raw.githubusercontent.com/dfci/matchminer-setup/HEAD/matchminer.tar.gz
tar -xzvf matchminer.tar.gz
sleep 2
docker cp matchminer mongo:/
sleep 1
docker exec mongo mongorestore matchminer

echo "SUCCESS. To view, navigate to http://localhost"