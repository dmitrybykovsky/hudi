#!/usr/bin/env bash

set -x

table=$1
version=$2
dr=`dirname $0`

if [ ! -e "jq" ]; then
    wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
    chmod +x ./jq
fi
schema="$(curl -X GET http://schema-registry:8081/subjects/dbserver1-postgres.inventory."$table"-value/versions/"$version" | ./jq '.schema | fromjson')"
hive --hiveconf schema="${schema}" --hiveconf table="${table}" -f "$dr/hive-sync.sql"