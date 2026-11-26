FROM alpine AS rclone-downloader
WORKDIR /rclone-download

RUN wget https://downloads.rclone.org/rclone-current-linux-amd64.zip &&  \
    unzip rclone-current-linux-amd64.zip &&  \
    mv rclone*linux-amd64/rclone /usr/bin/


# The apk package `postgresql-pg_cron` is built against Alpine's own PostgreSQL packages,
# not the one in /usr/local of the official image, so pg_cron is compiled from source.
FROM postgres:19-alpine AS pg-cron-builder
ARG PG_CRON_VERSION=1.6.8
WORKDIR /pg_cron

RUN apk add --no-cache build-base &&  \
    wget -O- "https://github.com/citusdata/pg_cron/archive/refs/tags/v${PG_CRON_VERSION}.tar.gz" | tar -xz --strip-components=1 &&  \
    make with_llvm=no &&  \
    make install with_llvm=no DESTDIR=/out


FROM postgres:19-alpine

# Defaults of the settings backup.sh and entrypoint.sh read at runtime (see README). BACKUP_S3_BUCKET has no default:
# every container sets its own.
ENV BACKUP_RETENTION_DAYS=30 \
    BACKUP_CRON="0 2 * * *" \
    CRON=disabled

VOLUME /backups

COPY --from=rclone-downloader /usr/bin/rclone /usr/bin/rclone
COPY --from=pg-cron-builder /out/usr/local /usr/local

COPY rclone.conf /etc/rclone.conf
COPY ./backup.sh /etc/periodic/daily/backup
COPY ./entrypoint.sh /kozalo/entrypoint.sh

RUN ["chmod", "+x", "/etc/periodic/daily/backup", "/kozalo/entrypoint.sh"]
ENTRYPOINT ["/kozalo/entrypoint.sh"]
CMD ["postgres"]
