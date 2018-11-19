#!/usr/bin/env bash
export DEBEZIUM_VERSION=0.8
./setup_demo.sh compose/postgres-kafka-hdfs.yml
curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @compose/register-postgres.json