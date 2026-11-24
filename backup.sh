#!/bin/sh

if [ ! -d "/backups/${POSTGRES_USER}" ]; then
    mkdir "/backups/${POSTGRES_USER}"
fi

# Dump the database
pg_dumpall -c -U "$POSTGRES_USER" | gzip > "/backups/${POSTGRES_USER}/${POSTGRES_USER}db_$(date +"%Y-%m-%d_%H_%M_%S").gz"

# Delete old backups
find /backups/ -type f -mtime +"${BACKUP_RETENTION_DAYS}" -name '*.gz' -delete

# Sync with Scaleway S3 Object Storage bucket
if [ -z "$BACKUP_S3_BUCKET" ]; then
    echo "BACKUP_S3_BUCKET is not set: the dump stays in /backups only" >&2
    exit 1
fi
rclone --config='/config/rclone.conf' sync "/backups/${POSTGRES_USER}/" "remote-s3:${BACKUP_S3_BUCKET}"
