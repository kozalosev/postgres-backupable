#!/bin/sh

if [ ! -f /config/rclone.conf ]
then
    echo "Mount your rclone.conf file to /config/rclone.conf"
    exit 1
fi

crond

# Command-line options take precedence over postgresql.conf and are also applied to the temporary server
# that initializes the database on the first start, so no restart is needed.
if [ "$CRON" = "enabled" ] && [ "$1" = "postgres" ]; then
    set -- "$@" -c shared_preload_libraries=pg_cron -c cron.database_name="${POSTGRES_DB:-${POSTGRES_USER:-postgres}}"
fi

exec docker-entrypoint.sh "$@"
