#!/bin/bash
set -eu
export MYSQL_PWD="$(cat /run/secrets/mysql_app_password)"
mysql --protocol=TCP --host=127.0.0.1 --connect-timeout=3 \
    --user=waterline_app --database=waterline_one \
    --batch --skip-column-names --execute='SELECT 1' >/dev/null 2>&1
