PostgreSQL + rclone + Scaleway S3
=================================
Based on: postgres:14.5-alpine

Additional environment variables
--------------------------------
* **BACKUP_S3_BUCKET** — the name of a bucket in your Scaleway Object storage.

Configuration file
------------------
Mount your `rclone.conf` file to `/config/rclone.conf`. [Example](rclone.conf) of the file.
