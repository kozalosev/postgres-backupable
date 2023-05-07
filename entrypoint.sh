#!/bin/sh

if [ ! -f /config/rclone.conf ]
then
    echo "Mount your rclone.conf file to /config/rclone.conf"
    exit 1
fi

crond

exec docker-entrypoint.sh "$@"
