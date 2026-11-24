PostgreSQL + rclone + Scaleway S3
=================================
[![Docker Hub image](https://img.shields.io/badge/Docker%20Hub-image-brightgreen)](https://hub.docker.com/r/kozalo/postgres-backupable)

Based on: postgres:14.5-alpine

Image tags
----------
* **14**, **14.1**, … — the major version of the image matches the major version of PostgreSQL. Pin the major tag in
  your configuration: a new major version of PostgreSQL can't read data directories of the previous one.
* **latest** — still points to the 14.x line but will be removed in the future. Don't rely on it.

Additional environment variables
--------------------------------
* **BACKUP_S3_BUCKET** — the name of a bucket in your Scaleway Object storage.
* **BACKUP_RETENTION_DAYS** — how many days of daily dumps to keep (30 by default). The bucket is synced with the
  local directory, so older dumps are deleted from S3 as well.
* **BACKUP_CRON** — when the backup runs, as five cron fields: minute, hour, day of month, month, day of week
  (`0 1 * * *` is every day at 01:00). The time is the container's, UTC unless `TZ` is set. Unset, it's Alpine's
  default of 02:00 every day. The container refuses to start if the value isn't five such fields.

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
    image: kozalo/postgres-backupable:14
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
