drop table ${hiveconf:table}_avro;

CREATE EXTERNAL TABLE ${hiveconf:table}_avro
PARTITIONED BY (`not_there` String) 
STORED AS AVRO
LOCATION '/user/hive/warehouse/${hiveconf:table}/'
TBLPROPERTIES ('avro.schema.literal'='${hiveconf:schema}');

drop table ${hiveconf:table};

add jar /var/hoodie/ws/docker/hoodie/hadoop/hive_base/target/hoodie-hadoop-mr-bundle.jar;

CREATE EXTERNAL TABLE ${hiveconf:table}
LIKE ${hiveconf:table}_avro 
ROW FORMAT SERDE 'org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe' 
STORED AS INPUTFORMAT 'com.uber.hoodie.hadoop.HoodieInputFormat' 
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat';

msck repair table ${hiveconf:table};
