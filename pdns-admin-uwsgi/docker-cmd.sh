#!/bin/bash

set -euo pipefail

# Download code
curl -sSL https://github.com/thomasDOTde/PowerDNS-Admin/archive/master.tar.gz | tar -xzC /opt/powerdns-admin --strip 1

# Install python stuff
sed -i '/python-ldap/d' /opt/powerdns-admin/requirements.txt
chown -R root: /opt/powerdns-admin
chown -R www-data: /opt/powerdns-admin/upload
pip install -r requirements.txt

# Generate secret key
[ -f /root/secret-key ] || tr -dc _A-Z-a-z-0-9 < /dev/urandom | head -c 32 > /root/secret-key || true
PDNS_ADMIN_SECRET_KEY="'$(cat /root/secret-key)'"

export PDNS_ADMIN_SECRET_KEY

# Configure pdns server env vars
: "${PDNS_ADMIN_PDNS_STATS_URL:=http://pdns:${PDNS_ENV_PDNS_webserver_port:-8081}/}"
: "${PDNS_ADMIN_PDNS_API_KEY:=${PDNS_ENV_PDNS_api_key:-}}"
: "${PDNS_ADMIN_PDNS_VERSION:=${PDNS_ENV_VERSION:-}}"

export PDNS_ADMIN_PDNS_STATS_URL PDNS_ADMIN_PDNS_API_KEY PDNS_ADMIN_PDNS_VERSION


case ${DBBACKEND} in
'mysql')
    # Configure mysql env vars
    : "${PDNS_ADMIN_SQLA_DB_BACKEND:=mysql}"
    : "${PDNS_ADMIN_SQLA_DB_HOST:=mysql}"
    : "${PDNS_ADMIN_SQLA_DB_PORT:=3306}"
    : "${PDNS_ADMIN_SQLA_DB_USER:=${MYSQL_ENV_MYSQL_USER:-root}}"
    if [ "${PDNS_ADMIN_SQLA_DB_USER}" = "'root'" ]; then
        : "${PDNS_ADMIN_SQLA_DB_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}"
    fi
    : "${PDNS_ADMIN_SQLA_DB_PASSWORD:=${MYSQL_ENV_MYSQL_PASSWORD:-powerdnsadmin}}"
    : "${PDNS_ADMIN_SQLA_DB_NAME:=${MYSQL_ENV_MYSQL_DATABASE:-powerdnsadmin}}"

    export PDNS_ADMIN_SQLA_DB_BACKEND PDNS_ADMIN_SQLA_DB_HOST PDNS_ADMIN_SQLA_DB_PORT PDNS_ADMIN_SQLA_DB_USER PDNS_ADMIN_SQLA_DB_PASSWORD PDNS_ADMIN_SQLA_DB_NAME    

    envtpl < /config.py.jinja2 > /opt/powerdns-admin/config.py

    # Initialize DB if needed
    MYSQL_COMMAND="mysql -h ${PDNS_ADMIN_SQLA_DB_HOST//\'/} -P ${PDNS_ADMIN_SQLA_DB_PORT//\'/} -u ${PDNS_ADMIN_SQLA_DB_USER//\'/} -p${PDNS_ADMIN_SQLA_DB_PASSWORD//\'/}"

    until $MYSQL_COMMAND -e ';' ; do
        >&2 echo 'MySQL is unavailable - sleeping'
        sleep 1
    done

    $MYSQL_COMMAND -e "CREATE DATABASE IF NOT EXISTS ${PDNS_ADMIN_SQLA_DB_NAME//\'/}"

    MYSQL_CHECK_IF_HAS_TABLE="SELECT COUNT(DISTINCT table_name) FROM information_schema.columns WHERE table_schema = '${PDNS_ADMIN_SQLA_DB_NAME//\'/}';"
    MYSQL_NUM_TABLE=$($MYSQL_COMMAND --batch --skip-column-names -e "$MYSQL_CHECK_IF_HAS_TABLE")
    if [ "$MYSQL_NUM_TABLE" -eq 0 ]; then
        python2 /opt/powerdns-admin/create_db.py
    fi
    ;;
'postgresql')
    # Configure postgresql env vars
    : "${PDNS_ADMIN_SQLA_DB_BACKEND:=postgresql}"
    : "${PDNS_ADMIN_SQLA_DB_HOST:=postgres}"
    : "${PDNS_ADMIN_SQLA_DB_PORT:=5432}"
    : "${PDNS_ADMIN_SQLA_DB_USER:=${POSTGRES_ENV_POSTGRES_USER:-postgres}}"
    : "${PDNS_ADMIN_SQLA_DB_PASSWORD:=${POSTGRES_ENV_POSTGRES_PASSWORD:-powerdns}}"
    : "${PGPASSWORD:=${PDNS_ADMIN_SQLA_DB_PASSWORD}}"
    : "${PDNS_ADMIN_SQLA_DB_NAME:=${POSTGRES_ENV_POSTGRES_DB:-${PDNS_ADMIN_SQLA_DB_USER}}}"

    export PDNS_ADMIN_SQLA_DB_BACKEND PDNS_ADMIN_SQLA_DB_HOST PDNS_ADMIN_SQLA_DB_PORT PDNS_ADMIN_SQLA_DB_USER PDNS_ADMIN_SQLA_DB_PASSWORD PDNS_ADMIN_SQLA_DB_NAME PGPASSWORD

    envtpl < /config.py.jinja2 > /opt/powerdns-admin/config.py

    # Initialize DB if needed
    PSQL_COMMAND="psql -h ${PDNS_ADMIN_SQLA_DB_HOST} -p ${PDNS_ADMIN_SQLA_DB_PORT} -U ${PDNS_ADMIN_SQLA_DB_USER} -w"

    until $PSQL_COMMAND -c ';' ; do
        >&2 echo 'PostgreSQL is unavailable - sleeping'
        sleep 1
    done

    # SQL Statements
    # Check whether given database exist
    CHECK_DB_SQL="SELECT COUNT(1) from pg_catalog.pg_database where datname = '$PDNS_ADMIN_SQLA_DB_NAME'"
    # Create database
    CREATE_DB_SQL="create database $PDNS_ADMIN_SQLA_DB_NAME"
    # Check if database has tables
    HAS_TABLE_SQL=" SELECT COUNT(DISTINCT tablename) from pg_catalog.pg_tables WHERE schemaname='public';"

    CHECK_DB_CMD="$PSQL_COMMAND -t -c \"$CHECK_DB_SQL\""
    DB_EXISTS=$(eval $CHECK_DB_CMD)
    
    if [ $DB_EXISTS -eq 0 ]; then
        echo "Database $PDNS_ADMIN_SQLA_DB_NAME does not exist, creating database..."
        $PSQL_COMMAND -c "$CREATE_DB_SQL"
    fi

    CHECK_TABLES_CMD="$PSQL_COMMAND $PDNS_ADMIN_SQLA_DB_NAME -t -c \"$HAS_TABLE_SQL\""
    NUM_TABLES_EXIST=$(eval $CHECK_TABLES_CMD)

    if [ "$NUM_TABLES_EXIST" -eq 0 ]; then
        echo "Database $PDNS_ADMIN_SQLA_DB_NAME is empty, creating db..."
        python2 /opt/powerdns-admin/create_db.py
    fi
    ;;
esac

# python2 /opt/powerdns-admin/db_upgrade.py

exec /usr/bin/supervisord