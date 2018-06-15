FROM python:3-stretch
LABEL maintainer="Jonathan Senecal <JSenecal@jonathansenecal.com>"

COPY src/ /

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
  curl \
  gnupg \
  apt-transport-https \
  && curl https://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add - \
  && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && apt-get update && apt-get install -y --no-install-recommends \
  postgresql-client \
  mysql-client \
  python3-pip python3-dev supervisor \
  libmariadbclient-dev-compat \
  libsasl2-dev libldap2-dev libssl-dev \
  libxml2-dev libxslt1-dev libxmlsec1-dev libffi-dev pkg-config \
  locales locales-all \
  yarn nginx \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /opt/powerdns-admin \
  && apt-get purge -y --auto-remove gnupg

WORKDIR /opt/powerdns-admin

RUN curl -sSL https://github.com/ngoduykhanh/PowerDNS-Admin/archive/master.tar.gz | tar -xzC /opt/powerdns-admin --strip 1 \
  && chown -R root: /opt/powerdns-admin \
  && chown -R www-data: /opt/powerdns-admin/upload \
  && pip install -r requirements.txt \
  && pip install envtpl uwsgi ldap psycopg2 \
  && apt-get purge -y --auto-remove curl

ENV PDNS_ADMIN_LOGIN_TITLE="PDNS" \
  PDNS_ADMIN_TIMEOUT=10 \
  PDNS_ADMIN_LOG_LEVEL="INFO" \
  PDNS_ADMIN_BASIC_ENABLED=True \
  PDNS_ADMIN_SIGNUP_ENABLED=True \
  PDNS_ADMIN_RECORDS_ALLOW_EDIT="['A', 'AAAA', 'CNAME', 'MX', 'TXT', 'SRV', 'NS', 'SOA']" \
  PDNS_ADMIN_FORWARD_RECORDS_ALLOW_EDIT="['A', 'AAAA', 'CAA', 'CNAME', 'MX', 'PTR', 'SPF', 'SRV', 'TXT', 'LOC' 'NS']" \
  PDNS_ADMIN_REVERSE_RECORDS_ALLOW_EDIT="['TXT', 'LOC', 'NS', 'PTR', 'SOA']"

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8 

EXPOSE 8181

VOLUME [ "/opt/powerdns-admin/upload" ]


COPY uwsgi.ini /etc/uwsgi/
COPY supervisord.conf /etc/supervisord.conf
COPY pdns-nginx.conf /etc/nginx/conf.d/default.conf
COPY config.py.jinja2 /
COPY docker-cmd.sh /

CMD [ "bash", "/docker-cmd.sh" ]
