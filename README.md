# PowerDNS 4.1 Docker Images based on Debian 9 (Stretch)

This repository contains four Docker images - pdns, pdns-recursor and pdns-admin.

Image **pdns** contains completely configurable [PowerDNS 4.1.x server](https://www.powerdns.com/) with mysql and gpgsql backends.

Image **pdns-recursor** contains completely configurable [PowerDNS 4.1.x recursor](https://www.powerdns.com/).

Images **pdns-admin** contains backend (gunicorn) for [PowerDNS Admin](https://github.com/ngoduykhanh/PowerDNS-Admin) web app, written in Flask, for managing PowerDNS servers. [PowerDNS Admin](https://github.com/ngoduykhanh/PowerDNS-Admin) is also completely configurable.

***

## pdns

Docker image with [PowerDNS 4.1.x server](https://www.powerdns.com/) with mysql and gpgsql backends.

Env vars for gmysql configuration:

```text
BACKEND=gmysql
PDNS_gmysql_host=mysql
PDNS_gmysql_port=3306
PDNS_gmysql_user=root
PDNS_gmysql_password=powerdns
PDNS_gmysql_dbname=powerdns
```

PowerDNS server is configurable via env vars. A backend must be selected with the `BACKEND` env var. Valid choices are `gmysql`, `gpgsql` and `gsqlite3` for MySQL, PostgreSQL and SQLite3 respectively.
Every variable starting with `PDNS_` will also be inserted into `/etc/pdns/pdns.conf` configuration file in the following way: prefix `PDNS_` will be stripped and every `_` will be replaced with `-`. For example, from above sql config, `PDNS_gmysql_host=mysql` will become `gmysql-host=sql` in `/etc/pdns/pdns.conf` file. This way, you can configure the PowerDNS server any way you need within a `docker run` command.

There is also a `SUPERMASTER_IPS` env var supported, which can be used to configure supermasters for slave dns server. [Docs](https://doc.powerdns.com/md/authoritative/modes-of-operation/#supermaster-automatic-provisioning-of-slaves). Multiple ip addresses separated by space should work.

All available settings can be found over [here](https://doc.powerdns.com/md/authoritative/settings/).

### pdns Examples

#### Master server with API enabled and with one slave server configured

```shell
docker run -d -p 53:53 -p 53:53/udp --name pdns-master \
  --hostname ns1.example.com \
  -e BACKEND=gmysql \
  -e PDNS_master=yes \
  -e PDNS_api=yes \
  -e PDNS_api_key=secret \
  -e PDNS_webserver=yes \
  -e PDNS_webserver_address=0.0.0.0 \
  -e PDNS_webserver_password=secret2 \
  -e PDNS_version_string=anonymous \
  -e PDNS_default_ttl=1500 \
  -e PDNS_soa_minimum_ttl=1200 \
  -e PDNS_default_soa_name=ns1.example.com \
  -e PDNS_default_soa_mail=hostmaster.example.com \
  -e PDNS_allow_axfr_ips=172.5.0.21 \
  -e PDNS_only_notify=172.5.0.21 \
  connectitnet/pdns
```

#### Slave server with supermaster

```shell
docker run -d -p 53:53 -p 53:53/udp --name pdns-slave \
  --hostname ns2.example.com --link mariadb:mysql \
  -e BACKEND=gmysql \
  -e PDNS_gmysql_dbname=powerdnsslave \
  -e PDNS_slave=yes \
  -e PDNS_version_string=anonymous \
  -e PDNS_disable_axfr=yes \
  -e PDNS_allow_notify_from=172.5.0.20 \
  -e SUPERMASTER_IPS=172.5.0.20 \
  connectitnet/pdns
```

## pdns-recursor

Docker image with [PowerDNS 4.1.x recursor](https://www.powerdns.com/).

PowerDNS recursor is configurable via env vars. Every variable starting with `PDNS_` will be inserted into `/etc/pdns/recursor.conf` configuration file in the following way: prefix `PDNS_` will be stripped and every `_` will be replaced with `-` just like above. This way, you can configure the PowerDNS recursor any way you need within a `docker run` command.

All available settings can be found over [here](https://doc.powerdns.com/md/recursor/settings/).

### pdns-recursor Examples

Recursor server with API enabled:

```shell
docker run -d -p 53:53 -p 53:53/udp --name pdns-recursor connectitnet/pdns-recursor
```

## pdns-admin

Docker image with [PowerDNS Admin](https://github.com/ngoduykhanh/PowerDNS-Admin) web app, written in Flask, for managing PowerDNS servers. This image contains the python part of the app running under gunicorn. It needs external *sql server.

Env vars for sql configuration:

```text
PDNS_ADMIN_SQLA_DB_HOST="'sql'"
PDNS_ADMIN_SQLA_DB_PORT="'3306'"
PDNS_ADMIN_SQLA_DB_USER="'root'"
PDNS_ADMIN_SQLA_DB_PASSWORD="'powerdnsadmin'"
PDNS_ADMIN_SQLA_DB_NAME="'powerdnsadmin'"
```

Similar to the `pdns` container, pdns-admin is also completely configurable via env vars. Prefix in this case is `PDNS_ADMIN_`, but there is one caveat: as the config file is a python source file, every string value must be quoted, as shown above. Double quotes are consumed by Bash, so the single quotes stay for Python. (Port number in this case is treated as string, because later on it's concatenated with hostname, user, etc in the db uri). Configuration from these env vars will be written to the `/opt/powerdns-admin/config.py` file.

### Connecting to the PowerDNS server

For the pdns-admin to make sense, it needs a PowerDNS server to manage. The PowerDNS server needs to have exposed API (example configuration for PowerDNS 4.x):

```text
api=yes
api-key=secret
webserver=yes
```

And again, PowerDNS connection is configured via env vars (it needs url of the PowerDNS server, api key and a version of PowerDNS server, for example 4.1.0):

```text
(name=default value)

PDNS_ADMIN_PDNS_STATS_URL="'http://pdns:8081/'"
PDNS_ADMIN_PDNS_API_KEY="''"
PDNS_ADMIN_PDNS_VERSION="''"
```

If this container is linked with pdns-
sql from this repo with alias `pdns`, it will be configured automatically and none of the env vars from above are needed to be specified.

### Persistent data

There is a directory with user uploads which should be persistent: `/opt/powerdns-admin/upload`

### pdns-admin-uwsgi Example

When linked with pdns-sql from this repo and with LDAP auth:

```text
docker run -d --name pdns-admin-uwsgi \
  --link mariadb:mysql --link pdns-master:pdns \
  -v pdns-admin-upload:/opt/powerdns-admin/upload \
  -e PDNS_ADMIN_LDAP_TYPE="'ldap'" \
  -e PDNS_ADMIN_LDAP_URI="'ldaps://your-ldap-server:636'" \
  -e PDNS_ADMIN_LDAP_USERNAME="'cn=dnsuser,ou=users,ou=services,dc=example,dc=com'" \
  -e PDNS_ADMIN_LDAP_PASSWORD="'dnsuser'" \
  -e PDNS_ADMIN_LDAP_SEARCH_BASE="'ou=System Admins,ou=People,dc=example,dc=com'" \
  -e PDNS_ADMIN_LDAP_USERNAMEFIELD="'uid'" \
  -e PDNS_ADMIN_LDAP_FILTER="'(objectClass=inetorgperson)'" \
  connectitnet/pdns-admin-uwsgi
```

## pdns-admin-nginx

Front-end image with nginx and static files for [PowerDNS Admin](https://github.com/ngoduykhanh/PowerDNS-Admin). Exposes port 80 for proxy connections, and expects a uWSGI backend image under `pdns-admin-uwsgi` alias.

### pdns-admin-nginx Example

```shell
docker run -d --name pdns-admin-nginx \
  --link pdns-admin-uwsgi:pdns-admin-uwsgi \
  connectitnet/pdns-admin-nginx
```