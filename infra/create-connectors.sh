#!/bin/bash

# Wait for Kafka Connect to be ready
echo "Waiting for Kafka Connect to be ready..."
until curl -s -f http://localhost:8083/connectors > /dev/null; do
  echo "Kafka Connect not ready yet. Waiting 5 seconds..."
  sleep 5
done
echo "Kafka Connect is ready!"

# Delete existing connectors if they exist
echo "Checking for existing connectors..."
CONNECTORS=$(curl -s http://localhost:8083/connectors)

if echo $CONNECTORS | grep -q "postgres-source"; then
  echo "Deleting existing postgres-source connector..."
  curl -s -X DELETE http://localhost:8083/connectors/postgres-source
fi

if echo $CONNECTORS | grep -q "elasticsearch-sink"; then
  echo "Deleting existing elasticsearch-sink connector..."
  curl -s -X DELETE http://localhost:8083/connectors/elasticsearch-sink
fi

if echo $CONNECTORS | grep -q "postgres-sink"; then
  echo "Deleting existing postgres-sink connector..."
  curl -s -X DELETE http://localhost:8083/connectors/postgres-sink
fi

# Create the source connector
echo "Creating postgres-source connector..."
curl -X POST \
  -H "Content-Type: application/json" \
  --data @postgres-source.json \
  http://localhost:8083/connectors

# Wait a few seconds for source connector to initialize
sleep 5

# Create the Elasticsearch sink connector
echo "Creating elasticsearch-sink connector..."
curl -X POST \
  -H "Content-Type: application/json" \
  --data @elasticsearch-sink.json \
  http://localhost:8083/connectors

# Create the Postgres sink connector
echo "Creating postgres-sink connector..."
curl -X POST \
  -H "Content-Type: application/json" \
  --data @postgres-sink.json \
  http://localhost:8083/connectors

echo "All connectors created. Checking status..."

# Check the status of all connectors
sleep 2
curl -s http://localhost:8083/connectors | jq .
echo "Done!" 