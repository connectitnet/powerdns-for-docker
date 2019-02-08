#!/bin/bash

set -euo pipefail

cd /opt/powerdns-admin
export FLASK_APP=app/__init__.py

# From https://github.com/docker-library/mariadb/blob/d50c0654f732f629150988ef4bc3f5e8f7d7ac7a/docker-entrypoint.sh#L21-L41
# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

# Generate secret key if not present
[ -f /root/secret-key ] || tr -dc _A-Z-a-z-0-9 < /dev/urandom | head -c 32 > /root/secret-key || true
PDNS_ADMIN_SECRET_KEY=$(cat /root/secret-key)

export PDNS_ADMIN_SECRET_KEY

# Configure pdns server env vars
: "${PDNS_PROTO:=http}"
: "${PDNS_HOST:=pdns}"
: "${PDNS_PORT:=${PDNS_ENV_PDNS_webserver_port:=8081}}"
: "${PDNS_API_URL:=${PDNS_PROTO}://${PDNS_HOST}:${PDNS_PORT}}"
file_env 'PDNS_API_KEY' "${PDNS_ENV_PDNS_api_key:-}"

case ${DBBACKEND} in
'mysql')
    # Configure mysql env vars
    : "${PDNS_ADMIN_SQLA_DB_BACKEND:=mysql}"
    : "${PDNS_ADMIN_SQLA_DB_HOST:=mysql}"
    : "${PDNS_ADMIN_SQLA_DB_PORT:=3306}"
    : "${PDNS_ADMIN_SQLA_DB_USER:=${MYSQL_ENV_MYSQL_USER:-root}}"
    if [ "${PDNS_ADMIN_SQLA_DB_USER}" = "'root'" ]; then
        file_env 'MYSQL_ROOT_PASSWORD' $MYSQL_ENV_MYSQL_ROOT_PASSWORD
        : "${PDNS_ADMIN_SQLA_DB_PASSWORD:=$MYSQL_ROOT_PASSWORD}"
    else
        file_env 'MYSQL_PASSWORD' ${MYSQL_ENV_MYSQL_PASSWORD:-powerdnsadmin}
        : "${PDNS_ADMIN_SQLA_DB_PASSWORD:=$MYSQL_PASSWORD}"
    fi
    : "${PDNS_ADMIN_SQLA_DB_NAME:=${MYSQL_ENV_MYSQL_DATABASE:-powerdnsadmin}}"

    export PDNS_ADMIN_SQLA_DB_BACKEND PDNS_ADMIN_SQLA_DB_HOST PDNS_ADMIN_SQLA_DB_PORT PDNS_ADMIN_SQLA_DB_USER PDNS_ADMIN_SQLA_DB_PASSWORD PDNS_ADMIN_SQLA_DB_NAME    

    envtpl < /config.py.jinja2 > /opt/powerdns-admin/config.py

    MYSQL_COMMAND="mysql -h ${PDNS_ADMIN_SQLA_DB_HOST//\'/} -P ${PDNS_ADMIN_SQLA_DB_PORT//\'/} -u ${PDNS_ADMIN_SQLA_DB_USER//\'/} -p${PDNS_ADMIN_SQLA_DB_PASSWORD//\'/}"

    function wait_for_mysql () {
        if [ ! -z ${DEBUG+0} ] && [ $DEBUG = 1 ]; then
            echo "Trying to execute> $1 -e ';'"
        fi
        until $1 -e ';' ; do
            >&2 echo 'MySQL is unavailable - sleeping'
            sleep 1
        done
    }

    wait_for_mysql "$MYSQL_COMMAND"
    ;;
'postgresql')
    # Configure postgresql env vars
    : "${PDNS_ADMIN_SQLA_DB_BACKEND:=postgresql}"
    : "${PDNS_ADMIN_SQLA_DB_HOST:=postgres}"
    : "${PDNS_ADMIN_SQLA_DB_PORT:=5432}"
    : "${PDNS_ADMIN_SQLA_DB_USER:=${POSTGRES_ENV_POSTGRES_USER:-postgres}}"
    file_env 'POSTGRES_PASSWORD' ${POSTGRES_ENV_POSTGRES_PASSWORD:-powerdns}
    : "${PDNS_ADMIN_SQLA_DB_PASSWORD:=$POSTGRES_PASSWORD}"
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
    ;;
*)
    echo "'DBBACKEND' Must be either 'mysql' or 'postgresql'... Sleeping forever"
    sleep infinity
    ;;
esac


DB_MIGRATION_DIR='/opt/powerdns-admin/migrations'

echo "===> Running DB Migration"
set +e
flask db migrate -m "Upgrade BD Schema" --directory ${DB_MIGRATION_DIR}
flask db upgrade --directory ${DB_MIGRATION_DIR}
set -e

echo "===> Update PDNS API connection info"
case ${DBBACKEND} in
'mysql')
    echo " --> Initial settings if not available in the DB"
    $MYSQL_COMMAND ${PDNS_ADMIN_SQLA_DB_NAME} -e "INSERT INTO setting (name, value) SELECT * FROM (SELECT 'pdns_api_url', '${PDNS_API_URL}') AS tmp WHERE NOT EXISTS (SELECT name FROM setting WHERE name = 'pdns_api_url') LIMIT 1;"
    $MYSQL_COMMAND ${PDNS_ADMIN_SQLA_DB_NAME} -e "INSERT INTO setting (name, value) SELECT * FROM (SELECT 'pdns_api_key', '${PDNS_API_KEY}') AS tmp WHERE NOT EXISTS (SELECT name FROM setting WHERE name = 'pdns_api_key') LIMIT 1;"

    
    echo " --> Update pdns api settings if changed from env vars"
    $MYSQL_COMMAND ${PDNS_ADMIN_SQLA_DB_NAME} -e "UPDATE setting SET value='${PDNS_API_URL}' WHERE name='pdns_api_url' AND value != '${PDNS_API_URL}';"
    $MYSQL_COMMAND ${PDNS_ADMIN_SQLA_DB_NAME} -e "UPDATE setting SET value='${PDNS_API_KEY}' WHERE name='pdns_api_key' AND value != '${PDNS_API_KEY}';"


    FALSE="False"
    if [ ! -z ${CREATEUSER+FALSE} ] && [ $CREATEUSER = "True" ]; then
        echo "Creating user ${PDNS_ADMIN_SQLA_DB_USER//\'/} for DB ${PDNS_ADMIN_SQLA_DB_NAME//\'/}"
        MYSQL_ROOT_COMMAND="mysql -h ${PDNS_ADMIN_SQLA_DB_HOST//\'/} -P ${PDNS_ADMIN_SQLA_DB_PORT//\'/} -u root -p${MYSQL_ROOT_PASSWORD//\'/}"
        wait_for_mysql "$MYSQL_ROOT_COMMAND"
        $MYSQL_ROOT_COMMAND -e "CREATE USER ${PDNS_ADMIN_SQLA_DB_USER//\'/};"
        $MYSQL_ROOT_COMMAND -e "GRANT ALL PRIVILEGES ON ${PDNS_ADMIN_SQLA_DB_NAME//\'/}.* TO ${PDNS_ADMIN_SQLA_DB_USER//\'/}@'%' IDENTIFIED BY '${PDNS_ADMIN_SQLA_DB_PASSWORD//\'/}';"
        $MYSQL_ROOT_COMMAND -e "FLUSH PRIVILEGES;"
    fi
    ;;
'postgresql')
    echo "postgresql is NOT IMPLEMENTED... Skipping!"
    ;;
esac

echo "===> Assets management"

echo " --> Restore custom assets"
tar -xvf staticfiles.tar

echo " --> Running Yarn"
yarn install --pure-lockfile

echo " --> Running Flask assets"
flask assets build

exec "$@"