FROM python:2-stretch
LABEL maintainer="Jonathan Senecal <JSenecal@jonathansenecal.com>"

RUN apt-get update && apt-get install -y --no-install-recommends \
  curl \
  gnupg

COPY src/ /

ENV DEBIAN_FRONTEND=noninteractive
RUN curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
  && apt-get update && apt-get install -y --no-install-recommends \
  postgresql-client \
  mysql-client \
  libxmlsec1-dev \
  uwsgi \
  python-ldap \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /opt/powerdns-admin \
  && curl -sSL https://github.com/thomasDOTde/PowerDNS-Admin/archive/master.tar.gz | tar -xzC /opt/powerdns-admin --strip 1 \
  && sed -i '/python-ldap/d' /opt/powerdns-admin/requirements.txt \
  && chown -R root: /opt/powerdns-admin \
  && chown -R www-data: /opt/powerdns-admin/upload \
  && apt-get purge -y --auto-remove curl gnupg

WORKDIR /opt/powerdns-admin

RUN pip install envtpl \
  && pip install -r requirements.txt \
  && rm -rf ~/.cache/*

ENV PDNS_ADMIN_LOGIN_TITLE="'PDNS'" \
  PDNS_ADMIN_TIMEOUT=10 \
  PDNS_ADMIN_LOG_LEVEL="'INFO'" \
  PDNS_ADMIN_BASIC_ENABLED=True \
  PDNS_ADMIN_SIGNUP_ENABLED=True \
  PDNS_ADMIN_RECORDS_ALLOW_EDIT="['SOA', 'NS', 'A', 'AAAA', 'CNAME', 'MX', 'TXT', 'SRV']"

EXPOSE 8181

VOLUME [ "/opt/powerdns-admin/upload" ]

COPY pdns-admin.ini /etc/uwsgi/conf.d/
RUN chown www-data: /etc/uwsgi/conf.d/pdns-admin.ini \
  && ln -s /etc/uwsgi/uwsgi.ini /etc/uwsgi.ini

COPY config.py.jinja2 /
COPY docker-cmd.sh /

CMD [ "/docker-cmd.sh" ]