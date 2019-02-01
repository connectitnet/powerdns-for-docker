FROM python:3-stretch
LABEL maintainer="Jonathan Senecal <JSenecal@jonathansenecal.com>"

ENV DEBIAN_FRONTEND=noninteractive

COPY src/ /

RUN apt-get update && apt-get install -y --no-install-recommends curl gnupg apt-transport-https \
  && apt-key adv --no-tty --fetch-keys https://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc \
  && apt-key adv --no-tty --fetch-keys https://repo.powerdns.com/FD380FBB-pub.asc \
  && ln /etc/apt/sources.list.d.available/* /etc/apt/sources.list.d/ \
  && apt-get update && apt-get install -y --no-install-recommends \
  pdns-server \
  pdns-backend-mysql \
  pdns-backend-pgsql \
  pdns-tools \
  postgresql-client \
  mysql-client \
  && apt-get purge -y --auto-remove curl gnupg \
  && rm -rf /var/lib/apt/lists/*

RUN pip3 install envtpl \
  && rm -rf ~/.cache/*

ENV VERSION=4.1 \
  PDNS_setuid=pdns \
  PDNS_setgid=pdns \
  PDNS_guardian=yes \
  PDNS_webserver=yes \
  PDNS_webserver_address=0.0.0.0 \
  PDNS_webserver_port=8081 
  

EXPOSE 53 53/udp 8081

COPY pdns.conf.jinja2 /etc/powerdns/
COPY docker-entrypoint.sh /

ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "/usr/sbin/pdns_server" ]
