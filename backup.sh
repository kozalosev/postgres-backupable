#!/bin/sh
# The daily backup: dumps every database, deletes the dumps older than BACKUP_RETENTION_DAYS and syncs the directory to
# the bucket. crond runs it (BACKUP_CRON), and its output reaches the container's log (see entrypoint.sh). Every line
# of its own starts with "backup:", and the last one is either "backup: synced ..." or "backup: FAILED at <step> ...",
# which is what to search or alert on.
set -o pipefail

log() {
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) backup: $*"
}

# fail <step> <exit code> [details]
fail() {
    log "FAILED at $1 (exit code $2)${3:+: $3}"
    exit "$2"
}

dir="/backups/${POSTGRES_USER}"
mkdir -p "$dir"
log "started for ${POSTGRES_USER}"

# Without pipefail the status would be gzip's, and a failed dump would leave an empty .gz to sync as a backup
file="${dir}/${POSTGRES_USER}db_$(date +"%Y-%m-%d_%H_%M_%S").gz"
pg_dumpall -c -U "$POSTGRES_USER" | gzip > "$file"
status=$?
if [ "$status" -ne 0 ]; then
    rm -f "$file"
    fail dump "$status"
fi
log "dumped ${file} ($(du -h "$file" | cut -f1))"

deleted=$(find /backups/ -type f -mtime +"${BACKUP_RETENTION_DAYS}" -name '*.gz' -print -delete | wc -l)
status=$?
[ "$status" -eq 0 ] || fail retention "$status"
log "deleted ${deleted} dumps older than ${BACKUP_RETENTION_DAYS} days"

[ -n "$BACKUP_S3_BUCKET" ] || fail sync 1 "BACKUP_S3_BUCKET is not set, the dump stays in ${dir} only"
# -v lists what was copied and deleted: a dump or two a day. Against an unreachable endpoint, rclone's retries times
# the S3 client's own go on for hours, and crond doesn't start the next run while this one lasts, so the sync gets an
# hour at most.
timeout 3600 rclone --config='/config/rclone.conf' sync "${dir}/" "remote-s3:${BACKUP_S3_BUCKET}" -v --stats-one-line 2>&1 |
    sed 's/^/backup: rclone: /'
status=$?
case "$status" in
    0) ;;
    124|143) fail sync "$status" "rclone didn't finish within an hour" ;;
    *) fail sync "$status" ;;
esac
log "synced to ${BACKUP_S3_BUCKET}"
