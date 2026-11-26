#!/bin/sh

if [ ! -f /config/rclone.conf ]
then
    echo "Mount your rclone.conf file to /config/rclone.conf"
    exit 1
fi

# The backup's output goes to the container's log. crond daemonizes with its stdio on /dev/null, and PID 1 will be
# postgres, another user whose file descriptors root can't open without CAP_SYS_PTRACE. So the job appends to a file,
# and a tail started here, before the exec, keeps this process's stdout and copies the file to it. -n 0: a restarted
# container doesn't repeat what it logged before.
# Each run first renames the previous run's file to backup.log.1, so the file never grows past one run. -F follows the
# name to the new file, prints all of it and says so in the log ("has been replaced; following end of new file").
# Truncating in place instead would lose the start of a run that outgrows the previous one before tail notices.
BACKUP_LOG=/var/log/backup.log
touch "$BACKUP_LOG"
tail -F -n 0 "$BACKUP_LOG" &
job="mv -f $BACKUP_LOG $BACKUP_LOG.1 2>/dev/null; run-parts /etc/periodic/daily >> $BACKUP_LOG 2>&1"

# The backup is /etc/periodic/daily/backup, run by Alpine's root crontab. The line is found by its command and
# rewritten whole: BACKUP_CRON (the Dockerfile's default is Alpine's own 02:00) or, set to an empty value, the line's
# current five fields, then the job. So a restart of the same container finds and rewrites it the same way.
if [ -n "$BACKUP_CRON" ] && { [ "$(echo "$BACKUP_CRON" | awk '{ print NF }')" != 5 ] || echo "$BACKUP_CRON" | grep -q '[^0-9*/,[:space:]-]'; }
then
    echo "BACKUP_CRON must be five cron fields (minute hour day month weekday), e.g. \"0 1 * * *\"; got \"$BACKUP_CRON\""
    exit 1
fi
crontab="$(awk -v schedule="$BACKUP_CRON" -v job="$job" '
    /[[:space:]]run-parts \/etc\/periodic\/daily/ {
        if (schedule == "") schedule = $1 " " $2 " " $3 " " $4 " " $5
        $0 = schedule "\t" job
    }
    { print }' /etc/crontabs/root)"
echo "$crontab" > /etc/crontabs/root

crond

# Command-line options take precedence over postgresql.conf and are also applied to the temporary server
# that initializes the database on the first start, so no restart is needed.
if [ "$CRON" = "enabled" ] && [ "$1" = "postgres" ]; then
    set -- "$@" -c shared_preload_libraries=pg_cron -c cron.database_name="${POSTGRES_DB:-${POSTGRES_USER:-postgres}}"
fi

exec docker-entrypoint.sh "$@"
