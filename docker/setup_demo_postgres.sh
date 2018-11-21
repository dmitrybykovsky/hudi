#!/usr/bin/env bash

export DEBEZIUM_VERSION=0.8
export MY_HUDI_EXTRA_VERSION=1.1-SNAPSHOT

rm -rf /tmp/my-kafka-transforms.jar
curl -fSL -o /tmp/my-kafka-transforms.jar \
https://github.com/dmitrybykovsky/kafkatransforms/releases/download/${MY_HUDI_EXTRA_VERSION}/kafka-transforms-${MY_HUDI_EXTRA_VERSION}.jar
cp /tmp/my-kafka-transforms.jar hoodie/hadoop/hive_base/target/

./setup_demo.sh compose/postgres-kafka-hdfs.yml

curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" \
http://localhost:8083/connectors/ -d @compose/register-postgres.json
