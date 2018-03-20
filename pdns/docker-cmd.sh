#!/bin/bash

set -euo pipefail

case ${BACKEND} in
'gmysql')
    # Configure mysql env vars
    : "${PDNS_gmysql_host:=mysql}"
    : "${PDNS_gmysql_port:=3306}"
    : "${PDNS_gmysql_user:=${MYSQL_ENV_MYSQL_USER:-root}}"
    if [ "${PDNS_gmysql_user}" = 'root' ]; then
        : "${PDNS_gmysql_password:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}"
    fi
    : "${PDNS_gmysql_password:=${MYSQL_ENV_MYSQL_PASSWORD:-powerdns}}"
    : "${PDNS_gmysql_dbname:=${MYSQL_ENV_MYSQL_DATABASE:-powerdns}}"
    PDNS_launch=gmysql

    export PDNS_gmysql_host PDNS_gmysql_port PDNS_gmysql_user PDNS_gmysql_password PDNS_gmysql_dbname PDNS_launch

    # Initialize DB if needed
    MYSQL_COMMAND="mysql -h ${PDNS_gmysql_host} -P ${PDNS_gmysql_port} -u ${PDNS_gmysql_user} -p${PDNS_gmysql_password}"

    until $MYSQL_COMMAND -e ';' ; do
        >&2 echo 'MySQL is unavailable - sleeping'
        sleep 1
    done

    $MYSQL_COMMAND -e "CREATE DATABASE IF NOT EXISTS ${PDNS_gmysql_dbname}"

    MYSQL_CHECK_IF_HAS_TABLE="SELECT COUNT(DISTINCT table_name) FROM information_schema.columns WHERE table_schema = '${PDNS_gmysql_dbname}';"
    MYSQL_NUM_TABLE=$($MYSQL_COMMAND --batch --skip-column-names -e "$MYSQL_CHECK_IF_HAS_TABLE")
    if [ "$MYSQL_NUM_TABLE" -eq 0 ]; then
        echo "Database $PDNS_gmysql_dbname is empty, importing mysql default schema..."
        $MYSQL_COMMAND -D "$PDNS_gmysql_dbname" < /usr/share/doc/pdns-backend-mysql/schema.mysql.sql
    fi

    # Configure supermasters if needed
    if [ "${SUPERMASTER_IPS:-}" ]; then
        $MYSQL_COMMAND -D "$PDNS_gmysql_dbname" -e "TRUNCATE supermasters;"
        MYSQL_INSERT_SUPERMASTERS=''
        for ip in $SUPERMASTER_IPS; do
            MYSQL_INSERT_SUPERMASTERS="${MYSQL_INSERT_SUPERMASTERS} INSERT INTO supermasters VALUES('${ip}', '${HOSTNAME}', 'admin');"
        done
        $MYSQL_COMMAND -D "$PDNS_gmysql_dbname" -e "$MYSQL_INSERT_SUPERMASTERS"
    fi
    ;;
'gpgsql')
    # Configure postgresql env vars
    : "${PDNS_gpgsql_host:=postgres}"
    : "${PDNS_gpgsql_port:=5432}"
    : "${PDNS_gpgsql_user:=${POSTGRES_ENV_POSTGRES_USER:-postgres}}"
    : "${PDNS_gpgsql_password:=${POSTGRES_ENV_POSTGRES_PASSWORD:-powerdns}}"
    : "${PGPASSWORD:=${PDNS_gpgsql_password}}"
    : "${PDNS_gpgsql_dbname:=${POSTGRES_ENV_POSTGRES_DB:-${PDNS_gpgsql_user}}}"
    PDNS_launch=gpgsql

    export PDNS_gpgsql_host PDNS_gpgsql_port PDNS_gpgsql_user PDNS_gpgsql_password PDNS_gpgsql_dbname PDNS_launch PGPASSWORD

    # Initialize DB if needed
    PSQL_COMMAND="psql -h ${PDNS_gpgsql_host} -p ${PDNS_gpgsql_port} -U ${PDNS_gpgsql_user} -w"

    until $PSQL_COMMAND -c ';' ; do
        >&2 echo 'PostgreSQL is unavailable - sleeping'
        sleep 1
    done

    # SQL Statements
    # Check whether given database exist
    CHECK_DB_SQL="SELECT COUNT(1) from pg_catalog.pg_database where datname = '$PDNS_gpgsql_dbname'"
    # Create database
    CREATE_DB_SQL="create database $PDNS_gpgsql_dbname"
    # Check if database has tables
    HAS_TABLE_SQL=" SELECT COUNT(DISTINCT tablename) from pg_catalog.pg_tables WHERE schemaname='public';"

    CHECK_DB_CMD="$PSQL_COMMAND -t -c \"$CHECK_DB_SQL\""
    DB_EXISTS=$(eval $CHECK_DB_CMD)

    if [ $DB_EXISTS -eq 0 ]; then
        echo "Database $PDNS_gpgsql_dbname does not exist, creating database..."
        $PSQL_COMMAND -c "$CREATE_DB_SQL"
    fi

    CHECK_TABLES_CMD="$PSQL_COMMAND $PDNS_gpgsql_dbname -t -c \"$HAS_TABLE_SQL\""
    NUM_TABLES_EXIST=$(eval $CHECK_TABLES_CMD)

    if [ "$NUM_TABLES_EXIST" -eq 0 ]; then
        echo "Database $PDNS_gpgsql_dbname is empty, importing pgsql default schema..."
        $PSQL_COMMAND $PDNS_gpgsql_dbname < /usr/share/doc/pdns-backend-pgsql/schema.pgsql.sql
    fi

    # Configure supermasters if needed
    if [ "${SUPERMASTER_IPS:-}" ]; then
        $PSQL_COMMAND $PDNS_gpgsql_dbname -c "TRUNCATE supermasters;"
        INSERT_SUPERMASTERS_SQL=''
        for i in $SUPERMASTER_IPS; do
            INSERT_SUPERMASTERS_SQL="${INSERT_SUPERMASTERS_SQL} INSERT INTO supermasters VALUES('${i}', '${HOSTNAME}', 'admin');"
        done
        $PSQL_COMMAND "$PDNS_gpgsql_dbname" -c "$INSERT_SUPERMASTERS_SQL"
    fi
    ;;
'gsqlite3')
        #TODO
    ;;
esac


# Create config file from template
envtpl < /etc/powerdns/pdns.conf.jinja2 > /etc/powerdns/pdns.conf

exec /usr/sbin/pdns_server