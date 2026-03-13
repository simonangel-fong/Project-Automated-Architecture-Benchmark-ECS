#!/usr/bin/env bash
set -euo pipefail

: "${BOOTSTRAP_SERVERS:?Need BOOTSTRAP_SERVERS}"
: "${TOPIC_NAME:?Need TOPIC_NAME}"
: "${PARTITIONS:=3}"
: "${REPLICATION_FACTOR:=3}"

export CLASSPATH="/opt/aws-msk-iam-auth.jar:${CLASSPATH:-}"

echo "Creating topic: ${TOPIC_NAME}"
/opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server "${BOOTSTRAP_SERVERS}" \
  --command-config /opt/kafka/config/client.properties \
  --create \
  --if-not-exists \
  --topic "${TOPIC_NAME}" \
  --partitions "${PARTITIONS}" \
  --replication-factor "${REPLICATION_FACTOR}"

echo "Done."
