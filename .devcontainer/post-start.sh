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

ensure_mobile_project_link() {
  echo "-- ensuring mobile-friendly project link"
  if [ -d /workspaces/Lira ]; then
    ln -sfn /workspaces/Lira "${HOME}/Lira" || true
    ls -ld "${HOME}/Lira" || true
  fi
}

ensure_sshd() {
  echo "-- ensuring sshd"
  if [ -n "${CODESPACE_SSH_PASSWORD:-}" ]; then
    echo "-- applying codespace SSH password from secret"
    printf 'codespace:%s\n' "${CODESPACE_SSH_PASSWORD}" | sudo chpasswd || true
    sudo sed -i 's/^#\\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
    sudo sed -i 's/^#\\?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config || true
  else
    echo "WARN: CODESPACE_SSH_PASSWORD secret is not set; direct phone SSH password login will not work"
  fi
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
    echo "-- installing tailscale"
    if [ -f /etc/apt/sources.list.d/yarn.list ]; then
      echo "-- disabling stale yarn apt source during tailscale install"
      sudo mv /etc/apt/sources.list.d/yarn.list /etc/apt/sources.list.d/yarn.list.disabled-by-lira-codespace || true
    fi
    curl -fsSL https://tailscale.com/install.sh | sh || {
      echo "WARN: tailscale install failed"
      return 0
    }
  fi

  if ! pgrep -x tailscaled >/dev/null 2>&1; then
    echo "-- starting tailscaled"
    sudo mkdir -p /var/lib/tailscale /var/run/tailscale
    sudo nohup tailscaled \
      --state=/var/lib/tailscale/tailscaled.state \
      --socket=/var/run/tailscale/tailscaled.sock \
      >/tmp/tailscaled.log 2>&1 &
    sleep 3
  fi

  if sudo tailscale status >/dev/null 2>&1; then
    sudo tailscale status --peers=false || true
    return 0
  fi

  if [ -z "${TS_AUTH_KEY:-}" ]; then
    echo "WARN: TS_AUTH_KEY Codespaces secret is not set; run 'tailscale up' manually or add the secret for auto-connect"
    return 0
  fi

  sudo tailscale up \
    --accept-routes \
    --ssh \
    --auth-key="${TS_AUTH_KEY}" \
    --hostname="${TAILSCALE_HOSTNAME:-lira-codespace}" || true
  sudo tailscale status --peers=false || true
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
  codex app-server daemon enable-remote-control || true
  codex app-server daemon version || true
}

ensure_path
ensure_mobile_project_link
ensure_sshd
ensure_tailscale
install_codex_if_needed
ensure_codex_auth
ensure_codex_app_server

echo "== Lira Codespace post-start complete =="
