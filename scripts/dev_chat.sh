#!/usr/bin/env bash
# Throwaway smoke client for Slice 1.7.
# Product code must not depend on this script.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON:-${ROOT_DIR}/.venv/bin/python}"

if [[ ! -x "${PYTHON_BIN}" ]]; then
  PYTHON_BIN="$(command -v python3 || command -v python)"
fi

PORT_FILE="$(
  cd "${ROOT_DIR}"
  "${PYTHON_BIN}" - <<'PY'
from daemon.core.config import DAEMON_PORT_FILE

print(DAEMON_PORT_FILE)
PY
)"

if [[ ! -f "${PORT_FILE}" ]]; then
  echo "No daemon .port file found at: ${PORT_FILE}" >&2
  echo "Start the daemon first: python daemon/main.py --dev" >&2
  exit 1
fi

PORT="$(tr -d '[:space:]' < "${PORT_FILE}")"

if [[ ! "${PORT}" =~ ^[0-9]+$ ]]; then
  echo "Daemon .port file is invalid: ${PORT_FILE}" >&2
  exit 1
fi

PROMPT="${*:-Say hello from Lira in one short sentence.}"
WAIT_SECONDS="${LIRA_DEV_CHAT_WAIT_SECONDS:-600}"

echo "Throwaway dev chat smoke. Reading port from: ${PORT_FILE}" >&2
echo "Waiting for daemon readiness on http://127.0.0.1:${PORT}/health" >&2

deadline=$((SECONDS + WAIT_SECONDS))
while true; do
  HEALTH_BODY="$(curl --silent --show-error "http://127.0.0.1:${PORT}/health" || true)"
  HEALTH_STATUS="$(
    "${PYTHON_BIN}" - "${HEALTH_BODY}" <<'PY'
import json
import sys

try:
    print(json.loads(sys.argv[1]).get("status", ""))
except Exception:
    print("")
PY
  )"

  if [[ "${HEALTH_STATUS}" == "ready" ]]; then
    break
  fi

  if [[ "${HEALTH_STATUS}" == "error" ]]; then
    echo "Daemon reported model load error: ${HEALTH_BODY}" >&2
    exit 1
  fi

  if (( SECONDS >= deadline )); then
    echo "Timed out waiting for daemon readiness: ${HEALTH_BODY}" >&2
    exit 1
  fi

  sleep 2
done

REQUEST_BODY="$(
  "${PYTHON_BIN}" - "${PROMPT}" <<'PY'
import json
import sys

print(json.dumps({"prompt": sys.argv[1], "max_tokens": 80}))
PY
)"

echo "POST http://127.0.0.1:${PORT}/chat/stream" >&2

curl --fail --silent --show-error --no-buffer -N \
  -H "Content-Type: application/json" \
  -d "${REQUEST_BODY}" \
  "http://127.0.0.1:${PORT}/chat/stream"
printf '\n'
