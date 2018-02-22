FROM python:stretch
MAINTAINER "Jonathan Senecal" <JSenecal@connectitnet.com>

COPY src/* /

RUN apt update \
  && apt-get install -y curl gnupg \
  && curl https://repo.powerdns.com/FD380FBB-pub.asc | apt-key add - \
  && apt-get update \
  && apt-get install -y pdns-recursor \
  && rm -rf /var/lib/apt/lists/*

RUN pip3 install envtpl \
  && rm -rf ~/.cache/*

RUN mkdir -p /etc/pdns/api.d

ENV VERSION=4.1 \
  PDNS_setuid=recursor \
  PDNS_setgid=recursor \
  PDNS_daemon=no

EXPOSE 53 53/udp

COPY recursor.conf.jinja2 /etc/powerdns/
COPY docker-cmd.sh /

CMD [ "/docker-cmd.sh" ]