#!/usr/bin/env bash

export DEBEZIUM_VERSION=0.9
export MY_HUDI_EXTRA_VERSION=0.1-SNAPSHOT

rm -rf kafkatransforms
git clone git@github.com:dmitrybykovsky/kafkatransforms.git
cd kafkatransforms
mvn clean package -DskipTests
cp target/kafka-transforms-${MY_HUDI_EXTRA_VERSION}.jar ../hoodie/hadoop/hive_base/target/my-kafka-transforms.jar
cd ..

./setup_demo.sh compose/postgres-kafka-hdfs.yml

curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" \
http://localhost:8083/connectors/ -d @compose/register-postgres.json
