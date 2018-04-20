FROM nginx:alpine
LABEL maintainer="Jonathan Senecal <JSenecal@connectitnet.com>"

RUN apk add --no-cache curl

RUN mkdir -p /opt/powerdns-admin \
  && curl -sSL https://github.com/ngoduykhanh/PowerDNS-Admin/archive/master.tar.gz \
    | tar -xzC /opt/powerdns-admin --strip 1 \
  && find /opt/powerdns-admin -path /opt/powerdns-admin/app/static -prune -o -type f -exec rm -f {} + \
  && chown -R root: /opt/powerdns-admin

EXPOSE 80

COPY pdns-nginx.conf /etc/nginx/conf.d/default.conf