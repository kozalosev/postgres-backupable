PostgreSQL + rclone + Scaleway S3
=================================
[![Docker Hub image](https://img.shields.io/badge/Docker%20Hub-image-brightgreen)](https://hub.docker.com/r/kozalo/postgres-backupable)

Based on: postgres:14.5-alpine

Additional environment variables
--------------------------------
* **BACKUP_S3_BUCKET** — the name of a bucket in your Scaleway Object storage.

Configuration file
------------------
Mount your `rclone.conf` file to `/config/rclone.conf`. [Example](rclone.conf) of the file.

Example of _docker-compose.yaml_
--------------------------------
```YAML
version: "3.7"
services:
  <...>
  postgres:
    image: kozalo/postgres-backupable
    container_name: postgresql
    environment:
      - POSTGRES_PORT
      - POSTGRES_DB
      - POSTGRES_USER
      - POSTGRES_PASSWORD
      - PGDATA=/var/lib/postgresql/data/pgdata
      - BACKUP_S3_BUCKET=<your bucket name>
    expose:
      - ${POSTGRES_PORT}
    volumes:
      - ./data:/var/lib/postgresql/data
      - ./rclone.conf:/config/rclone.conf
      - backups:/backups
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    restart: unless-stopped
    logging:
      driver: journald
volumes:
  backups:
```
