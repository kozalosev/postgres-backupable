#!/bin/sh

if [ ! -d "/backups/${POSTGRES_USER}" ]; then
    mkdir "/backups/${POSTGRES_USER}"
fi

# Dump the database
pg_dumpall -c -U "$POSTGRES_USER" | gzip > "/backups/${POSTGRES_USER}/${POSTGRES_USER}db_$(date +"%Y-%m-%d_%H_%M_%S").gz"

# Delete old backups
find /backups/ -type f -mtime +30 -name '*.gz' -delete

# Sync with Scaleway S3 Object Storage bucket
rclone --config='/config/rclone.conf' sync "/backups/${POSTGRES_USER}/" "remote-s3:${BACKUP_S3_BUCKET}"
