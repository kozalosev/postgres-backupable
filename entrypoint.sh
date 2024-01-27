#!/bin/sh

if [ ! -f /config/rclone.conf ]
then
    echo "Mount your rclone.conf file to /config/rclone.conf"
    exit 1
fi

crond

if [ "$CRON" == "enabled" ]; then
    sed -i "s/#shared_preload_libraries = ''/shared_preload_libraries = 'pg_cron'/" /var/lib/postgresql/data/postgresql.conf
fi

exec docker-entrypoint.sh "$@"
