# CDC Pipeline with Kafka, Debezium, and Elasticsearch

This setup enables Change Data Capture (CDC) from your PostgreSQL database to Elasticsearch using Kafka Connect with Debezium.

## Prerequisites

- Docker and Docker Compose
- Existing PostgreSQL database with logical replication enabled
- Existing Elasticsearch instance

## Setup Instructions

1. Start the infrastructure:
   ```bash
   docker-compose up -d
   ```

2. Check if Kafka Connect is running:
   ```bash
   curl http://localhost:8083/connectors
   ```

3. Configure PostgreSQL for CDC:
   
   - Ensure your PostgreSQL has the following settings in `postgresql.conf`:
     ```
     wal_level = logical
     max_wal_senders = 10
     max_replication_slots = 10
     ```
   
   - Check your current settings:
     ```sql
     SHOW wal_level;
     SHOW max_wal_senders;
     SHOW max_replication_slots;
     ```

## Connector Setup

### 1. Create PostgreSQL CDC Source Connector

Create the connector:
```bash
curl -X POST -H "Content-Type: application/json" --data @postgres-source.json http://localhost:8083/connectors
```

### 2. Create Elasticsearch Sink Connector

Create the connector:
```bash
curl -X POST -H "Content-Type: application/json" --data @elasticsearch-sink.json http://localhost:8083/connectors
```

### e. Create Postgres Sink Connector

Create the connector:
```bash
curl -X POST -H "Content-Type: application/json" --data @postgres-sink.json http://localhost:8083/connectors
```


## Monitoring

You can monitor Kafka and connectors through the Kafka UI at http://localhost:8089

## Troubleshooting

1. Check connector status:
   ```bash
   curl http://localhost:8083/connectors/product-postgres-source/status
   curl http://localhost:8083/connectors/elasticsearch-sink/status
   curl http://localhost:8083/connectors/postgres-sink/status
   
   ```

2. View connector logs:
   ```bash
   docker logs kafka-connect
   ```

3. If needed, delete and recreate a connector:
  Example:
   ```bash
   curl -X DELETE http://localhost:8083/connectors/postgres-source
   ```
