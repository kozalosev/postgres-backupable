FROM alpine as rclone-downloader
WORKDIR /rclone-download

RUN wget https://downloads.rclone.org/rclone-current-linux-amd64.zip &&  \
    unzip rclone-current-linux-amd64.zip &&  \
    mv rclone*linux-amd64/rclone /usr/bin/


FROM postgres:14.5-alpine

# Defaults of the settings backup.sh and entrypoint.sh read at runtime (see README). BACKUP_S3_BUCKET has no default:
# every container sets its own.
ENV BACKUP_RETENTION_DAYS=30 \
    BACKUP_CRON="0 2 * * *"

VOLUME /backups

COPY --from=rclone-downloader /usr/bin/rclone /usr/bin/rclone

COPY rclone.conf /etc/rclone.conf
COPY ./backup.sh /etc/periodic/daily/backup
COPY ./entrypoint.sh /kozalo/entrypoint.sh

RUN ["chmod", "+x", "/etc/periodic/daily/backup", "/kozalo/entrypoint.sh"]
ENTRYPOINT ["/kozalo/entrypoint.sh"]
CMD ["postgres"]
