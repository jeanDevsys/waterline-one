# MySQL 8.4 LTS fijado para compilaciones repetibles.
FROM mysql:8.4@sha256:b3b90af2a6552ae30c266fdb7d5dd55f3afb72404bb78d37fe8a23eb857fd3fb

COPY infra/mysql/my.cnf /etc/mysql/conf.d/waterline.cnf
COPY database/001_waterline_one.sql /docker-entrypoint-initdb.d/001_waterline_one.sql
COPY infra/mysql/900-users.sh /docker-entrypoint-initdb.d/900-users.sh
COPY infra/mysql/healthcheck.sh /usr/local/bin/waterline-healthcheck.sh
COPY infra/mysql/backup.sh /usr/local/bin/waterline-backup.sh
RUN chmod 0644 /etc/mysql/conf.d/waterline.cnf \
    && chmod 0644 /docker-entrypoint-initdb.d/900-users.sh \
    && chmod 0755 /usr/local/bin/waterline-healthcheck.sh /usr/local/bin/waterline-backup.sh
