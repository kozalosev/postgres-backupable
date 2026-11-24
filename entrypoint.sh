#!/bin/sh

if [ ! -f /config/rclone.conf ]
then
    echo "Mount your rclone.conf file to /config/rclone.conf"
    exit 1
fi

# The backup is /etc/periodic/daily/backup, run by Alpine's root crontab. BACKUP_CRON (the Dockerfile's default is
# Alpine's own 02:00) replaces the schedule of that line only; the line is matched by its command, so a restart of the
# same container finds it again. Set to an empty value, it leaves the crontab as it is.
if [ -n "$BACKUP_CRON" ]
then
    if [ "$(echo "$BACKUP_CRON" | awk '{ print NF }')" != 5 ] || echo "$BACKUP_CRON" | grep -q '[^0-9*/,[:space:]-]'
    then
        echo "BACKUP_CRON must be five cron fields (minute hour day month weekday), e.g. \"0 1 * * *\"; got \"$BACKUP_CRON\""
        exit 1
    fi
    sed -i "s|^.*[[:space:]]run-parts /etc/periodic/daily\$|$BACKUP_CRON\trun-parts /etc/periodic/daily|" /etc/crontabs/root
fi

crond

# Command-line options take precedence over postgresql.conf and are also applied to the temporary server
# that initializes the database on the first start, so no restart is needed.
if [ "$CRON" = "enabled" ] && [ "$1" = "postgres" ]; then
    set -- "$@" -c shared_preload_libraries=pg_cron -c cron.database_name="${POSTGRES_DB:-${POSTGRES_USER:-postgres}}"
fi

exec docker-entrypoint.sh "$@"
