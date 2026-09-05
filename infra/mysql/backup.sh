#!/bin/bash
set -eu
umask 077
export MYSQL_PWD="$(cat /run/secrets/mysql_root_password)"
mysqldump --user=root --single-transaction --routines --triggers --events \
    --hex-blob --no-tablespaces --set-gtid-purged=OFF \
    --databases waterline_one > "$1"
