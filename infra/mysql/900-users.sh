#!/bin/bash
# Se carga al iniciar y maneja un secreto local.
# No activar trazas.
waterline_app_secret="$(cat /run/secrets/mysql_app_password)"
if [[ ! "$waterline_app_secret" =~ ^[0-9a-f]{64}$ ]]; then
    echo 'The app secret must contain exactly 64 lowercase hexadecimal characters.' >&2
    exit 1
fi
docker_process_sql <<SQL
CREATE USER 'waterline_app'@'%' IDENTIFIED BY '${waterline_app_secret}';
GRANT 'wl_app_role' TO 'waterline_app'@'%';
SET DEFAULT ROLE 'wl_app_role' TO 'waterline_app'@'%';
SQL
unset waterline_app_secret
