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
BACKUP_LOG=/var/log/backup.log
touch "$BACKUP_LOG"
tail -F -n 0 "$BACKUP_LOG" &
job="run-parts /etc/periodic/daily >> $BACKUP_LOG 2>\&1"

# The backup is /etc/periodic/daily/backup, run by Alpine's root crontab. BACKUP_CRON (the Dockerfile's default is
# Alpine's own 02:00) replaces the schedule of that line; set to an empty value, it leaves the schedule as it is. The
# line is matched by its command, with or without the redirection, so a restart of the same container finds it again.
if [ -n "$BACKUP_CRON" ]
then
    if [ "$(echo "$BACKUP_CRON" | awk '{ print NF }')" != 5 ] || echo "$BACKUP_CRON" | grep -q '[^0-9*/,[:space:]-]'
    then
        echo "BACKUP_CRON must be five cron fields (minute hour day month weekday), e.g. \"0 1 * * *\"; got \"$BACKUP_CRON\""
        exit 1
    fi
    sed -i "s|^.*[[:space:]]run-parts /etc/periodic/daily.*\$|$BACKUP_CRON\t$job|" /etc/crontabs/root
else
    sed -i "s|[[:space:]]run-parts /etc/periodic/daily.*\$|\t$job|" /etc/crontabs/root
fi

crond

exec docker-entrypoint.sh "$@"
