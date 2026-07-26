#!/usr/bin/env bash
set -euo pipefail
cd /srv/parkplatz

APP_EMAIL="app@aplus-solution.de"
SMTP_PASSWORD_FILE="${SMTP_PASSWORD_FILE:-}"

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
docker compose -f docker-compose.prod.yml up -d --build --force-recreate api notifications

# Health and parking-space checks alone do not exercise password hashing,
# token persistence, or the users/refresh_tokens schema. Run the complete
# disposable auth lifecycle before considering the backend deploy successful.
FREIRAUM_API_BASE_URL=http://127.0.0.1:8000/api python3 ./ops/smoke-auth.py

for route in forgot-password reset-password account/security favorites onboarding; do
  install -d "/var/www/parkplatz/$route"
  cp /var/www/parkplatz/index.html "/var/www/parkplatz/$route/index.html"
done
