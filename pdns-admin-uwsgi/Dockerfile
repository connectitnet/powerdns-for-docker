FROM python:2-stretch
LABEL maintainer="Jonathan Senecal <JSenecal@jonathansenecal.com>"

RUN apk add --no-cache \
    curl \
    py-pip \
    libxslt \ 
    libxslt-dev \
    libxml2 \
    libxml2-dev \
    xmlsec \
    xmlsec-dev \
    uwsgi-python \
    py-mysqldb \
    py-psycopg2 \
    py-pyldap \
    py-cffi \
    py-bcrypt \
    mariadb-client \
    postgresql-client \
    gcc

RUN mkdir -p /opt/powerdns-admin \
  && curl -sSL https://github.com/thomasDOTde/PowerDNS-Admin/archive/master.tar.gz \
    | tar -xzC /opt/powerdns-admin --strip 1 \
  && sed -i '/python-ldap/d' /opt/powerdns-admin/requirements.txt \
  && sed -i '/bcrypt/d' /opt/powerdns-admin/requirements.txt \
  && chown -R root: /opt/powerdns-admin \
  && chown -R uwsgi: /opt/powerdns-admin/upload

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
RUN chown uwsgi: /etc/uwsgi/conf.d/pdns-admin.ini \
  && ln -s /etc/uwsgi/uwsgi.ini /etc/uwsgi.ini

COPY config.py.tpl /
COPY docker-cmd.sh /

CMD [ "/docker-cmd.sh" ]