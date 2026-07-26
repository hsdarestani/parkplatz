#!/usr/bin/env bash
set -euo pipefail
cd /srv/parkplatz

APP_EMAIL="app@aplus-solution.de"
SMTP_PASSWORD_FILE="${SMTP_PASSWORD_FILE:-}"
COMPOSE_FILE="docker-compose.prod.yml"
HEALTH_URL="http://127.0.0.1:8000/api/health"

cleanup_secret() {
  if [[ -n "$SMTP_PASSWORD_FILE" ]]; then
    rm -f -- "$SMTP_PASSWORD_FILE"
  fi
}
trap cleanup_secret EXIT

if [[ -z "$SMTP_PASSWORD_FILE" || ! -f "$SMTP_PASSWORD_FILE" ]]; then
  echo "SMTP_PASSWORD_FILE was not provided by the deployment workflow." >&2
  exit 1
fi

./ops/bootstrap-server.sh

# Read the repository secret from a short-lived file delivered over SSH. The
# password is never committed, printed, or placed in the remote command line.
python3 - "$SMTP_PASSWORD_FILE" <<'PY'
from pathlib import Path
import sys

ENV_PATH = Path(".env.production")
SECRET_PATH = Path(sys.argv[1])
APP_EMAIL = "app@aplus-solution.de"

password = SECRET_PATH.read_text(encoding="utf-8").rstrip("\r\n")
if not password:
    raise SystemExit("SMTP_PASSWORD is empty")
if "\n" in password or "\r" in password:
    raise SystemExit("SMTP_PASSWORD must be a single line")

updates = {
    "TRUST_SUPPORT_EMAIL": APP_EMAIL,
    "PRIMARY_EMAIL": APP_EMAIL,
    "NOMINATIM_CONTACT_EMAIL": APP_EMAIL,
    "SMTP_USERNAME": APP_EMAIL,
    "SMTP_FROM_EMAIL": APP_EMAIL,
    "SMTP_PASSWORD": password,
}


def dotenv_value(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


existing_lines = ENV_PATH.read_text(encoding="utf-8").splitlines()
written: set[str] = set()
output: list[str] = []

for line in existing_lines:
    if not line or line.lstrip().startswith("#") or "=" not in line:
        output.append(line)
        continue

    key = line.split("=", 1)[0].strip()
    if key in updates:
        output.append(f"{key}={dotenv_value(updates[key])}")
        written.add(key)
    else:
        output.append(line)

for key, value in updates.items():
    if key not in written:
        output.append(f"{key}={dotenv_value(value)}")

ENV_PATH.write_text("\n".join(output) + "\n", encoding="utf-8")
ENV_PATH.chmod(0o600)
print("Production SMTP mailbox configuration updated.")
PY

# Recreate services after updating the environment so the API and notification
# worker receive the active mailbox credentials.
docker compose -f "$COMPOSE_FILE" up -d --build --force-recreate api notifications

# force-recreate stops the healthy API created by bootstrap-server.sh. Wait for
# the replacement container to become healthy before running the auth lifecycle.
api_container_id="$(docker compose -f "$COMPOSE_FILE" ps -q api)"
if [[ -z "$api_container_id" ]]; then
  echo "API container was not created after applying SMTP settings." >&2
  docker compose -f "$COMPOSE_FILE" ps >&2
  exit 1
fi

api_ready=false
for attempt in $(seq 1 60); do
  if curl --fail --silent --show-error --max-time 5 "$HEALTH_URL" \
    | grep --quiet --extended-regexp '"status"[[:space:]]*:[[:space:]]*"ok"'; then
    api_ready=true
    break
  fi

  container_status="$(docker inspect --format '{{.State.Status}}' "$api_container_id" 2>/dev/null || true)"
  health_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$api_container_id" 2>/dev/null || true)"

  if [[ "$container_status" != "running" || "$health_status" == "unhealthy" ]]; then
    echo "API failed after SMTP restart (status=$container_status, health=$health_status)." >&2
    docker compose -f "$COMPOSE_FILE" ps >&2
    docker compose -f "$COMPOSE_FILE" logs --no-color --tail=250 api notifications >&2
    exit 1
  fi

  echo "Waiting for API after SMTP restart ($attempt/60, health=$health_status)..."
  sleep 2
done

if [[ "$api_ready" != true ]]; then
  echo "API did not become ready after applying SMTP settings." >&2
  docker compose -f "$COMPOSE_FILE" ps >&2
  docker compose -f "$COMPOSE_FILE" logs --no-color --tail=250 api notifications >&2
  exit 1
fi

# Health alone does not exercise password hashing, token persistence, or the
# users/refresh_tokens schema. Run the complete disposable auth lifecycle. If it
# fails, expose the API traceback and migration/schema state without printing
# credentials or user records.
if ! FREIRAUM_API_BASE_URL=http://127.0.0.1:8000/api python3 ./ops/smoke-auth.py; then
  echo "Production authentication lifecycle failed; collecting diagnostics." >&2
  echo "--- API and notification logs ---" >&2
  docker compose -f "$COMPOSE_FILE" logs --no-color --tail=350 api notifications >&2 || true
  echo "--- Alembic current state ---" >&2
  docker compose -f "$COMPOSE_FILE" exec -T api alembic current --verbose >&2 || true
  echo "--- Auth table schema ---" >&2
  docker compose -f "$COMPOSE_FILE" exec -T db sh -lc '
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
      -c "SELECT version_num FROM alembic_version ORDER BY version_num;" \
      -c "SELECT table_name, column_name, data_type, is_nullable FROM information_schema.columns WHERE table_schema = '\''public'\'' AND table_name IN ('\''users'\'', '\''refresh_tokens'\'', '\''password_reset_tokens'\'') ORDER BY table_name, ordinal_position;"
  ' >&2 || true
  exit 1
fi

for route in forgot-password reset-password account/security favorites onboarding; do
  install -d "/var/www/parkplatz/$route"
  cp /var/www/parkplatz/index.html "/var/www/parkplatz/$route/index.html"
done
