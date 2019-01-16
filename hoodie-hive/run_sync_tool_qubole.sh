#!/usr/bin/env bash

HIVE_HOME="/usr/lib/spark/lib/hive1.2"
HADOOP_HOME="/usr/lib/qubole/packages/hadoop2-2.6.0/hadoop2"

function error_exit {
    echo "$1" >&2   ## Send message to stderr. Exclude >&2 if you don't want it that way.
    exit "${2:-1}"  ## Return a code specified by $2 or 1 by default.
}

if [ -z "${HADOOP_HOME}" ]; then
  error_exit "Please make sure the environment variable HADOOP_HOME is setup"
fi

if [ -z "${HIVE_HOME}" ]; then
  error_exit "Please make sure the environment variable HIVE_HOME is setup"
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#Ensure we pick the right jar even for hive11 builds
HOODIE_HIVE_UBER_JAR="./hoodie-hive-bundle.jar"

if [ -z "$HADOOP_CONF_DIR" ]; then
  echo "setting hadoop conf dir"
  HADOOP_CONF_DIR="${HADOOP_HOME}/etc/hadoop"
fi

AWS_JARS=${HADOOP_HOME}/share/hadoop/tools/lib/*

## Include only specific packages from HIVE_HOME/lib to avoid version mismatches
HIVE_EXEC=`ls ${HIVE_HOME}/hive-exec-*.jar`
HIVE_SERVICE=`ls ${HIVE_HOME}/hive-service-*.jar | grep -v rpc`
HIVE_METASTORE=`ls ${HIVE_HOME}/hive-metastore-*.jar`
# Hive 1.x/CDH has standalone jdbc jar which is no longer available in 2.x
HIVE_JDBC=`ls ${HIVE_HOME}/hive-jdbc-*standalone*.jar`
if [ -z "${HIVE_JDBC}" ]; then
  HIVE_JDBC=`ls ${HIVE_HOME}/hive-jdbc-*.jar | grep -v handler`
fi
HIVE_JARS=$HIVE_METASTORE:$HIVE_SERVICE:$HIVE_EXEC:$HIVE_SERVICE:$HIVE_JDBC

HADOOP_HIVE_JARS=${AWS_JARS}:${HIVE_JARS}:${HADOOP_HOME}/share/hadoop/common/*:${HADOOP_HOME}/share/hadoop/mapreduce/*:${HADOOP_HOME}/share/hadoop/hdfs/*:${HADOOP_HOME}/share/hadoop/common/lib/*:${HADOOP_HOME}/share/hadoop/hdfs/lib/*

ls
echo "Running Command : java -cp ${HADOOP_HIVE_JARS}:${HADOOP_CONF_DIR}:$HOODIE_HIVE_UBER_JAR com.uber.hoodie.hive.HiveSyncTool $@"
zip -d $HOODIE_HIVE_UBER_JAR 'META-INF/*.SF' 'META-INF/*.RSA' 'META-INF/*.DSA'
java -verbose:jni -noverify -cp $HOODIE_HIVE_UBER_JAR:${HADOOP_HIVE_JARS}:${HADOOP_CONF_DIR} com.uber.hoodie.hive.HiveSyncTool "$@"
