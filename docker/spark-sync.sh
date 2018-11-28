#!/usr/bin/env bash

table=$1

DRIVER_CLASS_PATH_PREPEND=/var/hoodie/ws/packaging/hoodie-spark-bundle/target/lib/avro-1.8.2.jar
MY_HUDI_EXTRA=/var/hoodie/ws/docker/hoodie/hadoop/hive_base/target/my-kafka-transforms.jar

spark-submit \
--jars $MY_HUDI_EXTRA \
--driver-class-path /var/hoodie/ws/packaging/hoodie-spark-bundle/target/lib/avro-1.8.2.jar \
--class com.uber.hoodie.utilities.deltastreamer.HoodieDeltaStreamer $HUDI_UTILITIES_BUNDLE \
--schemaprovider-class com.uber.hoodie.utilities.schema.SchemaRegistryProvider \
--storage-type COPY_ON_WRITE \
--source-class com.uber.hoodie.utilities.sources.AvroKafkaSource \
--payload-class com.uber.hoodie.DeleteSupportAvroPayload \
--key-generator-class com.uber.hoodie.KeyGeneratorWithDeleted \
--target-base-path /user/hive/warehouse/${table} \
--target-table ${table} \
--source-ordering-field ts_ms \
--props /var/demo/config/kafka-source-postgres-${table}.properties