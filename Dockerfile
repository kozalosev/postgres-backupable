FROM alpine as rclone-downloader
WORKDIR /rclone-download

RUN wget https://downloads.rclone.org/rclone-current-linux-amd64.zip &&  \
    unzip rclone-current-linux-amd64.zip &&  \
    mv rclone*linux-amd64/rclone /usr/bin/


FROM postgres:14.5-alpine

ARG BACKUP_S3_BUCKET

VOLUME /backups

COPY --from=rclone-downloader /usr/bin/rclone /usr/bin/rclone

COPY rclone.conf /etc/rclone.conf
COPY ./backup.sh /etc/periodic/daily/
COPY ./entrypoint.sh /kozalo/entrypoint.sh

RUN ["chmod", "+x", "/etc/periodic/daily/backup.sh", "/kozalo/entrypoint.sh"]
ENTRYPOINT ["/kozalo/entrypoint.sh"]
CMD ["postgres"]
