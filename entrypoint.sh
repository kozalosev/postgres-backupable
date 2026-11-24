#!/bin/sh

if [ ! -f /config/rclone.conf ]
then
    echo "Mount your rclone.conf file to /config/rclone.conf"
    exit 1
fi

# The backup is /etc/periodic/daily/backup, run by Alpine's root crontab at 02:00. BACKUP_CRON replaces the schedule
# of that line only; the line is matched by its command, so a restart of the same container finds it again.
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

exec docker-entrypoint.sh "$@"
