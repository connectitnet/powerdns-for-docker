#!/usr/bin/bash

set -euo pipefail

# Create config file from template
envtpl < /etc/powerdns/recursor.conf.jinja2 > /etc/powerdns/recursor.conf

exec "$@"