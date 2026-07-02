#!/usr/bin/env bash
set -u

LOG_DIR="${HOME}/.codex-remote"
LOG_FILE="${LOG_DIR}/post-start.log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "== Lira Codespace post-start $(date -u +%Y-%m-%dT%H:%M:%SZ) =="

ensure_path() {
  export PATH="${HOME}/.local/bin:${HOME}/nvm/current/bin:/usr/local/share/nvm/current/bin:${PATH}"
}

ensure_sshd() {
  echo "-- ensuring sshd"
  if command -v service >/dev/null 2>&1; then
    sudo service ssh start || sudo service ssh restart || true
  fi
  if command -v sshd >/dev/null 2>&1 && ! pgrep -x sshd >/dev/null 2>&1; then
    sudo /usr/sbin/sshd || true
  fi
  pgrep -a sshd || echo "WARN: sshd is not running"
}

ensure_tailscale() {
  echo "-- ensuring tailscale"
  if ! command -v tailscale >/dev/null 2>&1; then
    echo "WARN: tailscale command not found; devcontainer feature may not have installed yet"
    return 0
  fi

  if tailscale status >/dev/null 2>&1; then
    tailscale status --peers=false || true
    return 0
  fi

  if [ -z "${TS_AUTH_KEY:-}" ]; then
    echo "WARN: TS_AUTH_KEY Codespaces secret is not set; run 'tailscale up' manually or add the secret for auto-connect"
    return 0
  fi

  tailscale up \
    --accept-routes \
    --ssh \
    --auth-key="${TS_AUTH_KEY}" \
    --hostname="${TAILSCALE_HOSTNAME:-lira-codespace}" || true
  tailscale status --peers=false || true
}

install_codex_if_needed() {
  ensure_path
  if command -v codex >/dev/null 2>&1 && codex --version >/dev/null 2>&1; then
    codex --version || true
    return 0
  fi

  echo "-- installing standalone Codex"
  curl -fsSL https://chatgpt.com/codex/install.sh | sh || {
    echo "WARN: Codex installer failed"
    return 0
  }
  ensure_path
  codex --version || true
}

ensure_codex_auth() {
  ensure_path
  echo "-- checking codex auth"
  if codex login status >/dev/null 2>&1; then
    codex login status || true
    return 0
  fi

  if [ -n "${CODEX_ACCESS_TOKEN:-}" ]; then
    printf '%s' "${CODEX_ACCESS_TOKEN}" | codex login --with-access-token || true
  elif [ -n "${OPENAI_API_KEY:-}" ]; then
    printf '%s' "${OPENAI_API_KEY}" | codex login --with-api-key || true
  else
    echo "WARN: Codex is not logged in; run 'codex login --device-auth' once inside this Codespace"
  fi
}

ensure_codex_app_server() {
  ensure_path
  echo "-- ensuring codex app-server daemon"
  if ! codex login status >/dev/null 2>&1; then
    echo "WARN: skipping app-server start until Codex auth is configured"
    return 0
  fi

  codex app-server daemon bootstrap || true
  codex app-server daemon start || true
  codex app-server daemon version || true
}

ensure_path
ensure_sshd
ensure_tailscale
install_codex_if_needed
ensure_codex_auth
ensure_codex_app_server

echo "== Lira Codespace post-start complete =="
