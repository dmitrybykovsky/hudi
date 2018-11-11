#!/usr/bin/env bash

yml_name=$1

# Create host mount directory and copy
mkdir -p /tmp/hadoop_name
mkdir -p /tmp/hadoop_data

WS_ROOT=`dirname $PWD`
# restart cluster
HUDI_WS=${WS_ROOT} docker-compose -f $yml_name down
#HUDI_WS=${WS_ROOT} docker-compose -f $yml_name pull
rm -rf /tmp/hadoop_data/*
rm -rf /tmp/hadoop_name/*
sleep 5
HUDI_WS=${WS_ROOT} docker-compose -f $yml_name up -d
sleep 15

docker exec -it adhoc-1 /bin/bash /var/hoodie/ws/docker/demo/setup_demo_container.sh
docker exec -it adhoc-2 /bin/bash /var/hoodie/ws/docker/demo/setup_demo_container.sh
