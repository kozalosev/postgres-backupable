#!/bin/sh
# The daily backup: dumps every database, copies the new dump to the bucket, then deletes the dumps older than
# BACKUP_RETENTION_DAYS from the bucket and all but the new one from the volume: the history lives in the bucket.
# crond runs it (BACKUP_CRON), and its output reaches the container's log (see entrypoint.sh). Every line of its own
# starts with "backup:", and the last one is either "backup: synced ..." or "backup: FAILED at <step> ...", which is
# what to search or alert on.
set -o pipefail

log() {
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) backup: $*"
}

# fail <step> <exit code> [details]
fail() {
    log "FAILED at $1 (exit code $2)${3:+: $3}"
    exit "$2"
}

# rclone_step <step> <rclone arguments...>
# Against an unreachable endpoint, rclone's retries times the S3 client's own go on for hours, and crond doesn't start
# the next run while this one lasts, so each call gets an hour at most. -v lists what was copied or deleted.
rclone_step() {
    step="$1"
    shift
    timeout 3600 rclone --config='/config/rclone.conf' "$@" -v --stats-one-line 2>&1 | sed 's/^/backup: rclone: /'
    status=$?
    case "$status" in
        0) ;;
        124|143) fail "$step" "$status" "rclone didn't finish within an hour" ;;
        *) fail "$step" "$status" ;;
    esac
}

dir="/backups/${POSTGRES_USER}"
mkdir -p "$dir"
log "started for ${POSTGRES_USER}"

# Zero or garbage would make the bucket's retention delete every dump, the new one included
case "$BACKUP_RETENTION_DAYS" in
    ''|*[!0-9]*|0) fail retention 1 "BACKUP_RETENTION_DAYS must be a positive number of days, got \"${BACKUP_RETENTION_DAYS}\"" ;;
esac

# Without pipefail the status would be gzip's, and a failed dump would leave an empty .gz to upload as a backup
file="${dir}/${POSTGRES_USER}db_$(date +"%Y-%m-%d_%H_%M_%S").gz"
pg_dumpall -c -U "$POSTGRES_USER" | gzip > "$file"
status=$?
if [ "$status" -ne 0 ]; then
    rm -f "$file"
    fail dump "$status"
fi
log "dumped ${file} ($(du -h "$file" | cut -f1))"

# copy, not sync: the bucket keeps the dumps the volume no longer has. It also uploads the dumps a failed run left
# behind, since nothing is deleted from the volume until they reach the bucket.
[ -n "$BACKUP_S3_BUCKET" ] || fail sync 1 "BACKUP_S3_BUCKET is not set, the dump stays in ${dir} only"
rclone_step sync copy "${dir}/" "remote-s3:${BACKUP_S3_BUCKET}" --include '*.gz'
log "uploaded to ${BACKUP_S3_BUCKET}"

# Every dump in the volume is in the bucket now, so only the new one is kept for a quick restore
deleted=$(find "$dir" -type f -name '*.gz' ! -path "$file" -print -delete | wc -l)
status=$?
[ "$status" -eq 0 ] || fail retention "$status"
log "deleted ${deleted} older dumps from ${dir}, kept the new one"

# --min-age compares the dump's own time, which rclone keeps in the object's metadata. Other objects of the bucket
# are left alone.
rclone_step retention delete "remote-s3:${BACKUP_S3_BUCKET}" --min-age "${BACKUP_RETENTION_DAYS}d" --include '*.gz'
log "deleted the dumps older than ${BACKUP_RETENTION_DAYS} days from ${BACKUP_S3_BUCKET}"

log "synced to ${BACKUP_S3_BUCKET}"
