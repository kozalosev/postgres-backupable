#!/bin/sh

# Dump the database
pg_dumpall -c -U "$POSTGRES_USER" | gzip > "/backups/${POSTGRES_USER}/${POSTGRES_USER}db_$(date +"%Y-%m-%d_%H_%M_%S").gz"

# Delete old backups
find /backups/ -type f -mtime +30 -name '*.gz' -delete

# Sync with Scaleway S3 Object Storage bucket
rclone sync "/backups/${POSTGRES_USER}/" "remote-s3:${BACKUP_S3_BUCKET}"
