#!/usr/bin/env bash
set -euo pipefail
cd /srv/parkplatz
./ops/bootstrap-server.sh

for route in forgot-password reset-password account/security; do
  install -d "/var/www/parkplatz/$route"
  cp /var/www/parkplatz/index.html "/var/www/parkplatz/$route/index.html"
done
