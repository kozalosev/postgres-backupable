PostgreSQL + rclone + Scaleway S3
=================================
[![Docker Hub image](https://img.shields.io/badge/Docker%20Hub-image-brightgreen)](https://hub.docker.com/r/kozalo/postgres-backupable)

Based on: postgres:19-alpine (with [pg_cron](https://github.com/citusdata/pg_cron) built in)

Image tags
----------
* **19**, **19.0**, **14**, **14.1**, … — the major version of the image matches the major version of PostgreSQL. Pin the major tag in
  your configuration: a new major version of PostgreSQL can't read data directories of the previous one.
* **latest** — still points to the 14.x line but will be removed in the future. Don't rely on it.

Additional environment variables
--------------------------------
* **BACKUP_S3_BUCKET** — the name of a bucket in your Scaleway Object storage.
* **BACKUP_RETENTION_DAYS** — how many days of daily dumps to keep (30 by default). The bucket is synced with the
  local directory, so older dumps are deleted from S3 as well.
* **CRON=enabled** — to load the *pg_cron* extension at startup. It's passed as command-line options
  (`shared_preload_libraries=pg_cron`, `cron.database_name=$POSTGRES_DB`), which take precedence over
  *postgresql.conf*. Run `CREATE EXTENSION pg_cron;` in that database once to start using it.

Upgrading from 14.x
-------------------
A new major version of PostgreSQL can't use the data directory of the previous one, but there's no need to go through
every version in between: a dump made by 14 can be restored into 19 directly.

1. Make a fresh dump with the old container: `docker exec postgresql /etc/periodic/daily/backup`
   (or take the latest `*.gz` file from `/backups/<user>/` or your bucket).
2. Stop the container and move the `./data` directory aside (don't delete it until you've checked the new database).
3. Switch the image to `kozalo/postgres-backupable:19`, temporarily without `CRON=enabled`, and start it with an empty
   `./data` directory.
4. Restore the dump: `gunzip -c <dump>.gz | docker exec -i postgresql psql -U "$POSTGRES_USER" -d postgres`.
   Errors about the current role and the existing database are expected and can be ignored.
5. Enable `CRON=enabled` back if you need it and restart the container.

The default `PGDATA` of the official image has changed in PostgreSQL 18+. The example below sets it explicitly, so it
keeps working.

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
    image: kozalo/postgres-backupable:19
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
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    restart: unless-stopped
    logging:
      driver: journald
```
