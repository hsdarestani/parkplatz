#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="docker-compose.prod.yml"
HEALTH_URL="http://127.0.0.1:8000/api/health"

command -v docker >/dev/null
docker compose version >/dev/null

install -d -m 700 /srv/parkplatz
cd /srv/parkplatz

if [[ ! -f .env.production ]]; then
  umask 077
  DB_PASSWORD="$(openssl rand -hex 24)"
  JWT_SECRET="$(openssl rand -hex 48)"
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

docker compose -f "$COMPOSE_FILE" up -d db
docker compose -f "$COMPOSE_FILE" run --rm api alembic upgrade head
docker compose -f "$COMPOSE_FILE" run --rm api python -m app.db.seed
docker compose -f "$COMPOSE_FILE" up -d --build

api_container_id="$(docker compose -f "$COMPOSE_FILE" ps -q api)"
if [[ -z "$api_container_id" ]]; then
  echo "API container was not created." >&2
  docker compose -f "$COMPOSE_FILE" ps >&2
  exit 1
fi

for attempt in $(seq 1 30); do
  if curl --fail --silent --show-error --max-time 5 "$HEALTH_URL" > /tmp/freiraum-health.json 2>/tmp/freiraum-health.err; then
    cat /tmp/freiraum-health.json
    echo
    echo "FREIRAUM API is ready."
    exit 0
  fi

  container_status="$(docker inspect --format '{{.State.Status}}' "$api_container_id" 2>/dev/null || true)"
  health_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$api_container_id" 2>/dev/null || true)"

  if [[ "$container_status" != "running" || "$health_status" == "unhealthy" ]]; then
    echo "API container failed while starting (status=$container_status, health=$health_status)." >&2
    docker compose -f "$COMPOSE_FILE" ps >&2
    docker compose -f "$COMPOSE_FILE" logs --no-color --tail=200 api >&2
    exit 1
  fi

  echo "Waiting for FREIRAUM API readiness ($attempt/30, health=$health_status)..."
  sleep 2
done

echo "API did not become ready before the deployment timeout." >&2
cat /tmp/freiraum-health.err >&2 || true
docker compose -f "$COMPOSE_FILE" ps >&2
docker compose -f "$COMPOSE_FILE" logs --no-color --tail=200 api >&2
exit 1
