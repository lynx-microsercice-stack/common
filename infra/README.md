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
   
   - If needed, modify these settings and restart PostgreSQL
   
   - Create a replication user:
     ```sql
     CREATE ROLE debezium WITH LOGIN PASSWORD 'dbz' REPLICATION;
     GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium;
     ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium;
     ```
   
   - Verify your PostgreSQL user has proper permissions:
     ```sql
     SELECT usename, userepl FROM pg_user WHERE usename = 'debezium';
     ```
     (The `userepl` column should be `t` for true)

   - Ensure your PostgreSQL is accessible from Docker containers by modifying `pg_hba.conf` to allow connections:
     ```
     host    all             debezium        0.0.0.0/0               md5
     host    replication     debezium        0.0.0.0/0               md5
     ```

## Connector Setup

### 1. Create PostgreSQL CDC Source Connector

Create a file named `postgres-source-connector.json` with the following content (adjust the connection details):

```json
{
  "name": "product-postgres-source",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "tasks.max": "1",
    "database.hostname": "host.docker.internal",
    "database.port": "5432",
    "database.user": "debezium",
    "database.password": "dbz",
    "database.dbname": "postgres",
    "topic.prefix": "product_db",
    "schema.include": "public",
    "table.include.list": "public.products",
    "plugin.name": "pgoutput",
    "slot.name": "debezium_products",
    "tombstones.on.delete": "false",
    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "false",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "true",
    "transforms": "unwrap",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.drop.tombstones": "false",
    "transforms.unwrap.delete.handling.mode": "rewrite",
    "transforms.unwrap.add.fields": "op,ts_ms"
  }
}
```

Create the connector:
```bash
curl -X POST -H "Content-Type: application/json" --data @postgres-source-connector.json http://localhost:8083/connectors
```

### 2. Create Elasticsearch Sink Connector

Create a file named `elasticsearch-sink-connector.json`:

```json
{
  "name": "elasticsearch-sink",
  "config": {
    "connector.class": "io.confluent.connect.elasticsearch.ElasticsearchSinkConnector",
    "tasks.max": "1",
    "topics": "product_db.public.products",
    "connection.url": "http://host.docker.internal:9200",
    "type.name": "_doc",
    "key.ignore": "false",
    "schema.ignore": "true",
    "behavior.on.null.values": "delete",
    "behavior.on.malformed.documents": "warn",
    "transforms": "extractKey",
    "transforms.extractKey.type": "org.apache.kafka.connect.transforms.ExtractField$Key",
    "transforms.extractKey.field": "id",
    "write.method": "upsert",
    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "false",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "true"
  }
}
```

Create the connector:
```bash
curl -X POST -H "Content-Type: application/json" --data @elasticsearch-sink-connector.json http://localhost:8083/connectors
```

## Monitoring

You can monitor Kafka and connectors through the Kafka UI at http://localhost:8089

## Troubleshooting

1. Check connector status:
   ```bash
   curl http://localhost:8083/connectors/product-postgres-source/status
   curl http://localhost:8083/connectors/elasticsearch-sink/status
   ```

2. View connector logs:
   ```bash
   docker logs kafka-connect
   ```

3. If needed, delete and recreate a connector:
   ```bash
   curl -X DELETE http://localhost:8083/connectors/product-postgres-source
   ```

4. Test PostgreSQL connection from Kafka Connect container:
   ```bash
   docker exec -it kafka-connect bash
   psql -h host.docker.internal -U debezium -d postgres
   ```

5. Check if PostgreSQL replication slot is created:
   ```sql
   SELECT * FROM pg_replication_slots;
   ```

6. If you're having connection issues, verify PostgreSQL is listening on all addresses:
   ```sql
   SHOW listen_addresses;
   ```
   It should be set to '*' or include the Docker network address. 