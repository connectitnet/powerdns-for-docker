FROM python:3-stretch
LABEL maintainer="Jonathan Senecal <JSenecal@jonathansenecal.com>"

COPY src/ /

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
  curl \
  gnupg \
  && curl https://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add - \
  && apt-get update && apt-get install -y --no-install-recommends \
  postgresql-client \
  mysql-client \
  python3-pip python3-dev supervisor \
  libmariadbclient-dev-compat \
  libsasl2-dev libldap2-dev libssl-dev \
  libxml2-dev libxslt1-dev libxmlsec1-dev libffi-dev pkg-config \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /opt/powerdns-admin \
  && apt-get purge -y --auto-remove gnupg

WORKDIR /opt/powerdns-admin

ENV PDNS_ADMIN_LOGIN_TITLE="PDNS" \
  PDNS_ADMIN_TIMEOUT=10 \
  PDNS_ADMIN_LOG_LEVEL="INFO" \
  PDNS_ADMIN_BASIC_ENABLED=True \
  PDNS_ADMIN_SIGNUP_ENABLED=True \
  PDNS_ADMIN_RECORDS_ALLOW_EDIT="['SOA', 'NS', 'A', 'AAAA', 'CNAME', 'MX', 'TXT', 'SRV']" \
  PDNS_ADMIN_FORWARD_RECORDS_ALLOW_EDIT="['A', 'AAAA', 'CAA', 'CNAME', 'MX', 'PTR', 'SPF', 'SRV', 'TXT', 'LOC' 'NS']" \
  PDNS_ADMIN_REVERSE_RECORDS_ALLOW_EDIT="['SOA', 'TXT', 'LOC', 'NS', 'PTR']"

EXPOSE 8181

VOLUME [ "/opt/powerdns-admin/upload" ]

RUN pip install envtpl uwsgi ldap psycopg2

COPY uwsgi.ini /etc/uwsgi/
COPY supervisord.conf /etc/supervisord.conf
COPY config.py.jinja2 /
COPY docker-cmd.sh /

CMD [ "bash", "/docker-cmd.sh" ]
