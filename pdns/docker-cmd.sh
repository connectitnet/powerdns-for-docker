#!/usr/bin/bash

set -euo pipefail

# Create config file from template
envtpl < /etc/powerdns/pdns.conf.jinja2 > /etc/powerdns/pdns.conf

exec /usr/sbin/pdns_server