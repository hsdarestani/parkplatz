#!/usr/bin/env bash
set -euo pipefail
command -v docker >/dev/null; docker compose version >/dev/null
install -d -m 700 /srv/parkplatz
cd /srv/parkplatz
if [[ ! -f .env.production ]]; then
  umask 077
  DB_PASSWORD="$(openssl rand -hex 24)"; JWT_SECRET="$(openssl rand -hex 48)"
  cat > .env.production <<ENV
POSTGRES_DB=freiraum
POSTGRES_USER=freiraum
POSTGRES_PASSWORD=$DB_PASSWORD
DATABASE_URL=postgresql+psycopg://freiraum:$DB_PASSWORD@db:5432/freiraum
JWT_SECRET=$JWT_SECRET
ENVIRONMENT=production
ENV
fi
chmod 600 .env.production
docker compose -f docker-compose.prod.yml up -d db
docker compose -f docker-compose.prod.yml run --rm api alembic upgrade head
docker compose -f docker-compose.prod.yml run --rm api python -m app.db.seed
docker compose -f docker-compose.prod.yml up -d --build
curl --fail --retry 12 --retry-delay 2 http://127.0.0.1:8000/api/health
