#!/usr/bin/env bash
set -euo pipefail
cd /srv/parkplatz
./ops/bootstrap-server.sh

sed -i 's/^TRUST_SUPPORT_EMAIL=info@aplus-solution\.de$/TRUST_SUPPORT_EMAIL=parkplatz@aplus-solution.de/' .env.production
sed -i 's/^TRUST_SUPPORT_EMAIL=parkplat@aplus-solution\.de$/TRUST_SUPPORT_EMAIL=parkplatz@aplus-solution.de/' .env.production
sed -i 's/^SMTP_FROM_EMAIL=info@aplus-solution\.de$/SMTP_FROM_EMAIL=parkplatz@aplus-solution.de/' .env.production
sed -i 's/^SMTP_FROM_EMAIL=parkplat@aplus-solution\.de$/SMTP_FROM_EMAIL=parkplatz@aplus-solution.de/' .env.production
sed -i 's/^PRIMARY_EMAIL=parkplat@aplus-solution\.de$/PRIMARY_EMAIL=parkplatz@aplus-solution.de/' .env.production
sed -i 's/^NOMINATIM_CONTACT_EMAIL=parkplat@aplus-solution\.de$/NOMINATIM_CONTACT_EMAIL=parkplatz@aplus-solution.de/' .env.production
for setting in \
  'PRIMARY_EMAIL=parkplatz@aplus-solution.de' \
  'NOMINATIM_CONTACT_EMAIL=parkplatz@aplus-solution.de' \
  'MARKETPLACE_UPLOAD_DIR=/var/lib/freiraum/marketplace-media' \
  'MARKETPLACE_IMAGE_MAX_BYTES=8388608' \
  'OPENAI_VISION_MODEL=gpt-5-mini'; do
  key="${setting%%=*}"
  grep --quiet "^${key}=" .env.production || printf '%s\n' "$setting" >> .env.production
done

docker compose -f docker-compose.prod.yml up -d --build

for route in forgot-password reset-password account/security favorites onboarding; do
  install -d "/var/www/parkplatz/$route"
  cp /var/www/parkplatz/index.html "/var/www/parkplatz/$route/index.html"
done
