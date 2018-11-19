# Demo: PostgreSQL - Kafka - HDFS

Let's use a real world example to see how hudi works end to end. For this purpose, a self contained
data infrastructure is brought up in a local docker cluster within your computer.
This demo will demonstrate how to incrementally ingest data from PostgreSQL into HDFS Data Lake.
We are going to use the following components:

   * Debezium Kafka Connector to Postgres is going to be used to incrementally ingest data from PostgreSQL into Kafka.
   * Kafka broker
   * Schema Registry to support avro ingestion/consumption
   * Hudi to upsert the data into HDFS and provide incremental access for downstream processing
   * Other components from Hadoop ecosystem

This demo assumes that you are using Mac laptop

## Prerequisites

  * Docker Setup :  For Mac, Please follow the steps as defined in [https://docs.docker.com/v17.12/docker-for-mac/install/]. For running Spark-SQL queries, please ensure atleast 6 GB and 4 CPUs are allocated to Docker (See Docker -> Preferences -> Advanced). Otherwise, spark-SQL queries could be killed because of memory issues.
  * kafkacat : A command-line utility to publish/consume from kafka topics. Use `brew install kafkacat` to install kafkacat
  * jq
  * /etc/hosts : The demo references many services running in container by the hostname. Add the following settings to /etc/hosts
  ```
   127.0.0.1 adhoc-1
   127.0.0.1 adhoc-2
   127.0.0.1 namenode
   127.0.0.1 datanode1
   127.0.0.1 hiveserver
   127.0.0.1 hivemetastore
   127.0.0.1 kafkabroker
   127.0.0.1 sparkmaster
   127.0.0.1 zookeeper
  ```

## Setting up Docker Cluster


### Build Hoodie

The first step is to build hoodie
```
git clone https://github.com/dmitrybykovsky/hudi.git
cd hudi
git checkout postgres-kafka-hdfs-demo
mvn package -DskipTests
```

### Bringing up Demo Cluster

The next step is to run the docker compose script and setup configs for bringing up the cluster.
This should pull the docker images from docker hub and setup docker cluster.

```
cd docker
./setup_demo_postgres.sh
```

At this point, the docker cluster will be up and running. The demo cluster brings up the following services

   * HDFS Services (NameNode, DataNode)
   * Spark Master and Worker
   * Hive Services (Metastore, HiveServer2 along with PostgresDB)
   * Kafka Broker and a Zookeeper Node (Kakfa will be used as upstream source for the demo)
   * Adhoc containers to run Hudi/Hive CLI commands
   * Confluent Schema Registry
   * Kafka Connect

### Step 0 : Open three more terminal windows

First terminal is going to be used to emulate transactional system.
Open psql shell in the first terminal
```
docker-compose -f compose/postgres-kafka-hdfs.yml exec postgres env PGOPTIONS="--search_path=inventory" bash -c 'psql -U $POSTGRES_USER postgres'
```

We will refer to this terminal as Postgres terminal

Second terminal is going to be used to emulate ETL.
In real life these steps will be scheduled in some orhestration framework like Oozie or Airflow.
Open shell session with adhoc-2 container in the second terminal
```
docker exec -it adhoc-2 /bin/bash
```

We will refer to this terminal as ETL terminal

Third terminal is going to be used to validate the ingestion into Data Lake
Open shell session with adhoc-2 container and then hive shell in the third terminal
```
docker exec -it adhoc-2 /bin/bash
beeline \
-u jdbc:hive2://hiveserver:10000 \
--hiveconf hive.input.format=org.apache.hadoop.hive.ql.io.HiveInputFormat \
--hiveconf hive.stats.autogather=false
```

We will refer to this terminal as Hive terminal

### Step 1 : Explore transactional system

In Postgres terminal:

List the available table
```
\dt
```

In this demo we will be using `customers` table. Let's explore it
```
select * from customers;
```

### Step 2 : Ingest the initial snapshot of transactional data into Kafka

When we brought up demo cluster we executed `setup_demo_postgres.sh` script.
In this script we registered Postgres Debezium Connector with Kafka Connect.
Upon registration the following happened:
   * Separate kafka topics were created for all the postgres tables
   * Avro schemas for all the tables were published into Schema Registry
   * Initial snapshots were ingested into Kafka topics

Explore avro schema of `dbserver1-postgres.inventory.customers` topic published in Schema Registry
In main terminal:
```
curl -X GET http://localhost:8081/subjects/dbserver1-postgres.inventory.customers-value/versions/1 | jq '.schema | fromjson'
```

Use `kafka-avro-console-consumer` to explore `dbserver1-postgres.inventory.customers` topic
In main terminal:
```
docker-compose -f compose/postgres-kafka-hdfs.yml exec schema-registry /usr/bin/kafka-avro-console-consumer \
    --bootstrap-server kafkabroker:9092 \
    --from-beginning \
    --property print.key=true \
    --property schema.registry.url=http://schema-registry:8081 \
    --topic dbserver1-postgres.inventory.customers
```
Note that all the records from postgres `customer` table have been ingested into Kafka.

### Step 3 : Ingest the initial snapshot from Kafka into Data Lake

Hudi comes with a tool named DeltaStreamer. This tool can connect to variety of data sources (including Kafka) to
pull changes and apply to Hudi dataset using upsert/insert primitives. Here, we will use the tool to download
avro data from kafka topic and ingest to COPY_ON_WRITE table. This tool
automatically initializes the datasets in the file-system if they do not exist yet.

In ETL terminal:

Ingest snapshot of `customer` table from Kafka into HDFS
```
spark-submit \
--class com.uber.hoodie.utilities.deltastreamer.HoodieDeltaStreamer $HUDI_UTILITIES_BUNDLE \
--schemaprovider-class com.uber.hoodie.utilities.schema.SchemaRegistryProvider \
--storage-type COPY_ON_WRITE \
--source-class com.uber.hoodie.utilities.sources.AvroKafkaSource \
--target-base-path /user/hive/warehouse/customers_postgres \
--target-table customers_postgres \
--source-ordering-field ts_ms \
--props /var/demo/config/kafka-source-postgres-customers.properties
```
Note that
   * We delegated all the heavy lifting of upserts into HDFS to `HoodieDeltaStreamer`
   * We rely on `SchemaRegistryProvider` to extract schema information of topics from Schema Registry
   * The data is ingested into `/user/hive/warehouse/customers_postgres` of HDFS
   * `kafka-source-postgres.properties` contains bunch of extra details. Check it out
   * The storage type is COPY_ON_WRITE. Another option is MERGE_ON_READ. Refer to Hudi Documentation for more details

You can use HDFS web-browser to look at the datasets
`http://localhost:50070/explorer.html#/user/hive/warehouse`.

You can explore the new partition folder created in the dataset along with a "deltacommit"
file under .hoodie which signals a successful commit.

### Step 4: Sync with Hive

At this step, the datasets are available in HDFS. We need to sync with Hive to create new Hive tables and add partitions
in order to run Hive queries against those datasets.

In ETL terminal:

```
/var/hoodie/ws/hoodie-hive/run_sync_tool.sh \
--jdbc-url jdbc:hive2://hiveserver:10000 \
--user hive \
--pass hive \
--partitioned-by default \
-partition-value-extractor com.uber.hoodie.hive.MultiPartKeysValueExtractor \
--base-path /user/hive/warehouse/customers_postgres \
--database default \
--table customers_postgres
```

After executing the above command a hive table named `customers_postgres` is created
which provides Read-Optimized view for the Copy On Write dataset.

### Step 5: Run Hive Queries

In Hive terminal:

List all the hive tables.
```
show tables;
```
Note that `customers_postgres` has been created.

Check out the structure of `customers_postgres` table
```
describe customers_postgres;
```

Check out the snapshot of the data
```
select * from customers_postgres;
select id, first_name, last_name, email, ts_ms, deleted from customers_postgres;
```

### Step 6: Insert a new record into `customers` table in postgres

In Postgres terminal:
```
insert into customers (first_name, last_name, email) values ('D','B','d.n@g.com');
```

Use `kafka-avro-console-consumer` to explore `dbserver1-postgres.inventory.customers` topic
In main terminal:
```
docker-compose -f compose/postgres-kafka-hdfs.yml exec schema-registry /usr/bin/kafka-avro-console-consumer \
    --bootstrap-server kafkabroker:9092 \
    --from-beginning \
    --property print.key=true \
    --property schema.registry.url=http://schema-registry:8081 \
    --topic dbserver1-postgres.inventory.customers
```
Note that the new record has been ingested into Kafka.

In ETL terminal:
```
spark-submit \
--class com.uber.hoodie.utilities.deltastreamer.HoodieDeltaStreamer $HUDI_UTILITIES_BUNDLE \
--schemaprovider-class com.uber.hoodie.utilities.schema.SchemaRegistryProvider \
--storage-type COPY_ON_WRITE \
--source-class com.uber.hoodie.utilities.sources.AvroKafkaSource \
--target-base-path /user/hive/warehouse/customers_postgres \
--target-table customers_postgres \
--source-ordering-field ts_ms \
--props /var/demo/config/kafka-source-postgres-customers.properties

/var/hoodie/ws/hoodie-hive/run_sync_tool.sh \
--jdbc-url jdbc:hive2://hiveserver:10000 \
--user hive \
--pass hive \
--partitioned-by default \
-partition-value-extractor com.uber.hoodie.hive.MultiPartKeysValueExtractor \
--base-path /user/hive/warehouse/customers_postgres \
--database default \
--table customers_postgres
```

In Hive terminal:
```
select * from customers_postgres;
select id, first_name, last_name, email, ts_ms, deleted from customers_postgres;
```
Note that new record has been inserted into hive table

### Step 7: Update a record in `customers` table in postgres

In Postgres terminal:
```
update customers set first_name = 'Dmitry' where id = 1005;
```

Use `kafka-avro-console-consumer` to explore `dbserver1-postgres.inventory.customers` topic
In main terminal:
```
docker-compose -f compose/postgres-kafka-hdfs.yml exec schema-registry /usr/bin/kafka-avro-console-consumer \
    --bootstrap-server kafkabroker:9092 \
    --from-beginning \
    --property print.key=true \
    --property schema.registry.url=http://schema-registry:8081 \
    --topic dbserver1-postgres.inventory.customers
```
Note that the updated record has been ingested into Kafka.

In ETL terminal:
```
spark-submit \
--class com.uber.hoodie.utilities.deltastreamer.HoodieDeltaStreamer $HUDI_UTILITIES_BUNDLE \
--schemaprovider-class com.uber.hoodie.utilities.schema.SchemaRegistryProvider \
--storage-type COPY_ON_WRITE \
--source-class com.uber.hoodie.utilities.sources.AvroKafkaSource \
--target-base-path /user/hive/warehouse/customers_postgres \
--target-table customers_postgres \
--source-ordering-field ts_ms \
--props /var/demo/config/kafka-source-postgres-customers.properties

/var/hoodie/ws/hoodie-hive/run_sync_tool.sh \
--jdbc-url jdbc:hive2://hiveserver:10000 \
--user hive \
--pass hive \
--partitioned-by default \
-partition-value-extractor com.uber.hoodie.hive.MultiPartKeysValueExtractor \
--base-path /user/hive/warehouse/customers_postgres \
--database default \
--table customers_postgres
```

In Hive terminal:
```
select * from customers_postgres;
select id, first_name, last_name, email, ts_ms, deleted from customers_postgres;
```
Note that the record has been updated

### Step 8: Delete a record from `customers` table in postgres

In Postgres terminal:
```
delete from customers where id = 1005;
```

Use `kafka-avro-console-consumer` to explore `dbserver1-postgres.inventory.customers` topic
In main terminal:
```
docker-compose -f compose/postgres-kafka-hdfs.yml exec schema-registry /usr/bin/kafka-avro-console-consumer \
    --bootstrap-server kafkabroker:9092 \
    --from-beginning \
    --property print.key=true \
    --property schema.registry.url=http://schema-registry:8081 \
    --topic dbserver1-postgres.inventory.customers
```
Note that the deleted record has been ingested into Kafka as an update with `deleted = true`.

In ETL terminal:
```
spark-submit \
--class com.uber.hoodie.utilities.deltastreamer.HoodieDeltaStreamer $HUDI_UTILITIES_BUNDLE \
--schemaprovider-class com.uber.hoodie.utilities.schema.SchemaRegistryProvider \
--storage-type COPY_ON_WRITE \
--source-class com.uber.hoodie.utilities.sources.AvroKafkaSource \
--target-base-path /user/hive/warehouse/customers_postgres \
--target-table customers_postgres \
--source-ordering-field ts_ms \
--props /var/demo/config/kafka-source-postgres-customers.properties

/var/hoodie/ws/hoodie-hive/run_sync_tool.sh \
--jdbc-url jdbc:hive2://hiveserver:10000 \
--user hive \
--pass hive \
--partitioned-by default \
-partition-value-extractor com.uber.hoodie.hive.MultiPartKeysValueExtractor \
--base-path /user/hive/warehouse/customers_postgres \
--database default \
--table customers_postgres
```

In Hive terminal:
```
select * from customers_postgres;
select id, first_name, last_name, email, ts_ms, deleted from customers_postgres;
```
Note that the record has been updated

### Step 9: Clean up

In main terminal
```
docker-compose -f compose/postgres-kafka-hdfs.yml down
```

[How to load multiple tables](README_multitable.md)

TODO Example for S3