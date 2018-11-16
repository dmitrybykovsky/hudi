FROM debezium/connect:0.8

ENV DEBEZIUM_VERSION=0.8.3.Final

RUN rm -rf /tmp/kafka-transforms-1.0-SNAPSHOT.jar &&\
    curl -fSL -o /tmp/kafka-transforms-1.0-SNAPSHOT.jar https://github.com/dmitrybykovsky/kafkatransforms/releases/download/1.0-SNAPSHOT/kafka-transforms-1.0-SNAPSHOT.jar &&\
    cp /tmp/kafka-transforms-1.0-SNAPSHOT.jar /kafka/connect/debezium-connector-postgres/ &&\
    cp /tmp/kafka-transforms-1.0-SNAPSHOT.jar /kafka/libs

