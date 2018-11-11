#!/usr/bin/env bash

./setup_demo.sh compose/postgres-kafka-hdfs.yml
curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @compose/register-postgres.json