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
* **BACKUP_S3_BUCKET** — the name of a bucket in your Scaleway Object storage. Required: without it, the dumps stay
  in `/backups` and every backup run ends with an error.
* **BACKUP_RETENTION_DAYS** — how many days of daily dumps to keep in the bucket (30 by default); older ones are
  deleted from it. Only `*.gz` files are deleted, and other objects in the bucket are left alone. The history is kept
  in the bucket only: `/backups/<user>/` holds just the latest dump, plus any dumps that haven't reached the bucket
  yet.
* **BACKUP_CRON** — when the backup runs, as five cron fields: minute, hour, day of month, month, day of week
  (`0 1 * * *` is every day at 01:00). The time is the container's, UTC unless `TZ` is set. The default is
  `0 2 * * *`, Alpine's own time for daily jobs. The container refuses to start if the value isn't five such fields.

Logs
----
The backup writes to the container's log (`docker logs`), next to PostgreSQL's own lines. Each line of its own starts
with `backup:`, and every run ends with one of two:

```
2026-11-25T01:30:02Z backup: synced to kozalo-backup-example
2026-11-25T01:30:01Z backup: FAILED at sync (exit code 1): BACKUP_S3_BUCKET is not set, the dump stays in /backups/user only
```

The steps are `dump`, `sync` and `retention`, in that order. A failed dump leaves no file behind, so nothing broken
reaches the bucket. A failed sync deletes nothing: the dumps wait in `/backups/<user>/` and go up with the next
successful run. Each rclone call gets an hour at most: rclone retrying an unreachable endpoint would otherwise run for
hours and keep the next night's backup from starting. To be warned about failures, alert on `backup: FAILED`, and on no
`backup: synced` for longer than the schedule's period: that also catches a backup that didn't run at all.

Inside the container, the scheduled run is also kept in `/var/log/backup.log`, and the previous one in
`/var/log/backup.log.1`: each run starts by replacing the older file, so they don't grow. Every run in the container's
log is preceded by `tail: /var/log/backup.log has been replaced; following end of new file`, which is expected.

All of this applies to scheduled runs. To test the setup without waiting for the schedule, run a backup by hand with
`docker exec <container> /etc/periodic/daily/backup`: its lines look the same but go to your terminal, not to the
container's log or these files.

Configuration file
------------------
Mount your `rclone.conf` file to `/config/rclone.conf`. [Example](rclone.conf) of the file.

Example of _docker-compose.yaml_
--------------------------------
```YAML
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
