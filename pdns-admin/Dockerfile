FROM python:3-stretch
LABEL maintainer="Jonathan Senecal <JSenecal@jonathansenecal.com>"

ENV DEBIAN_FRONTEND=noninteractive

COPY src/ /

RUN apt-get update && apt-get install -y --no-install-recommends curl gnupg apt-transport-https \
  && apt-key adv --no-tty --fetch-keys https://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc \
  && apt-key adv --no-tty --fetch-keys https://dl.yarnpkg.com/debian/pubkey.gpg \
  && curl -sSL https://deb.nodesource.com/setup_10.x | bash - \
  && ln /etc/apt/sources.list.d.available/* /etc/apt/sources.list.d/ \
  && apt-get update && apt-get install -y --no-install-recommends \
  postgresql-client \
  mysql-client \
  python3-pip python3-dev supervisor \
  libmariadbclient-dev-compat \
  libsasl2-dev libldap2-dev libssl-dev \
  libxml2-dev libxslt1-dev libxmlsec1-dev libffi-dev pkg-config \
  locales locales-all \
  nodejs yarn \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /opt/powerdns-admin \
  && apt-get purge -y --auto-remove gnupg apt-transport-https

WORKDIR /opt/powerdns-admin

VOLUME [ "/opt/powerdns-admin/app/static", "/opt/powerdns-admin/app/upload" ]


RUN curl -sSL https://github.com/ngoduykhanh/PowerDNS-Admin/archive/master.tar.gz | tar -xzC /opt/powerdns-admin --strip 1 \
  && chown -R root: /opt/powerdns-admin \
  && pip install --upgrade pip envtpl psycopg2 \
  && pip install -r requirements.txt \
  && tar -cf staticfiles.tar app/static \
  && rm -rf /opt/powerdns-admin/app/static/*

ENV DBBACKEND='mysql' \
  PDNS_ADMIN_LOGIN_TITLE="PDNS" \
  PDNS_ADMIN_TIMEOUT=10 \
  PDNS_ADMIN_LOG_LEVEL="INFO" \
  PDNS_ADMIN_BASIC_ENABLED=True \
  PDNS_ADMIN_SIGNUP_ENABLED=True \
  PDNS_ADMIN_RECORDS_ALLOW_EDIT="['A', 'AAAA', 'CAA', 'CNAME', 'MX', 'PTR', 'SPF', 'SRV', 'TXT', 'LOC', 'DS', 'NS', 'SOA', 'PTR']" \
  PDNS_ADMIN_REVERSE_RECORDS_ALLOW_EDIT="['PTR', 'TXT', 'LOC', 'NS', 'SOA']" \
  PDNS_ADMIN_DNSSEC_ADMINS_ONLY=False \
  PDNS_ADMIN_BG_DOMAIN_UPDATES=False

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8 

EXPOSE 8080

COPY supervisord.conf /etc/supervisord.conf

COPY config.py.jinja2 /
COPY docker-entrypoint.sh /

HEALTHCHECK --interval=30s --timeout=3s --start-period=3m CMD curl --fail http://127.0.0.1:8080 || exit 1

ENTRYPOINT [ "bash", "/docker-entrypoint.sh" ]
CMD [ "supervisord", "-c", "/etc/supervisord.conf" ]
