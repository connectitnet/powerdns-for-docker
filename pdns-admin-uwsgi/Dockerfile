FROM python:2-stretch
LABEL maintainer="Jonathan Senecal <JSenecal@jonathansenecal.com>"

COPY src/ /

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
  curl \
  gnupg \
  && curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
  && apt-get update && apt-get install -y --no-install-recommends \
  postgresql-client \
  mysql-client \
  libxmlsec1-dev \
  supervisor \
  python-ldap \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /opt/powerdns-admin \
  && apt-get purge -y --auto-remove gnupg

WORKDIR /opt/powerdns-admin

ENV PDNS_ADMIN_LOGIN_TITLE="'PDNS'" \
  PDNS_ADMIN_TIMEOUT=10 \
  PDNS_ADMIN_LOG_LEVEL="'INFO'" \
  PDNS_ADMIN_BASIC_ENABLED=True \
  PDNS_ADMIN_SIGNUP_ENABLED=True \
  PDNS_ADMIN_RECORDS_ALLOW_EDIT="['SOA', 'NS', 'A', 'AAAA', 'CNAME', 'MX', 'TXT', 'SRV']"

EXPOSE 8181

VOLUME [ "/opt/powerdns-admin/upload" ]

RUN pip install envtpl uwsgi ldap \
  && ln -s /usr/lib/python2.7/plat-x86_64-linux-gnu/_sysconfigdata_nd.py /usr/lib/python2.7/
COPY uwsgi.ini /etc/uwsgi/
COPY supervisord.conf /etc/supervisord.conf
COPY config.py.jinja2 /
COPY docker-cmd.sh /

CMD [ "bash", "/docker-cmd.sh" ]