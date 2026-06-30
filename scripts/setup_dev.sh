#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN_VENV="${ROOT_DIR}/.venv"
BONSAI_VENV="${ROOT_DIR}/.venv-bonsai"
MAIN_REQUIREMENTS="${ROOT_DIR}/requirements.txt"
BONSAI_REQUIREMENTS="${ROOT_DIR}/bonsai_sidecar/requirements.txt"
MIN_MACOS_MAJOR=14
BREW_PREFIX="/opt/homebrew"

step=""

fail() {
  local message="$1"
  printf 'ERROR: %s\n' "${message}" >&2
  exit 1
}

on_error() {
  local exit_code=$?
  if [[ -n "${step}" ]]; then
    printf 'ERROR: step failed: %s (exit %s)\n' "${step}" "${exit_code}" >&2
  else
    printf 'ERROR: setup failed (exit %s)\n' "${exit_code}" >&2
  fi
  exit "${exit_code}"
}

trap on_error ERR

run() {
  step="$1"
  shift
  printf '\n==> %s\n' "${step}"
  "$@"
  maybe_inject_failure "${step}"
}

maybe_inject_failure() {
  local completed_step="$1"
  if [[ "${LIRA_SETUP_DEV_INJECT_FAILURE_AFTER:-}" == "${completed_step}" ]]; then
    fail "injected failure after step: ${completed_step}"
  fi
}

version_major() {
  local version="$1"
  printf '%s\n' "${version%%.*}"
}

ensure_macos_arm64() {
  local os_name arch macos_version macos_major
  os_name="$(uname -s)"
  arch="$(uname -m)"
  macos_version="$(sw_vers -productVersion)"
  macos_major="$(version_major "${macos_version}")"

  [[ "${os_name}" == "Darwin" ]] || fail "Lira setup requires macOS; found ${os_name}."
  [[ "${arch}" == "arm64" ]] || fail "Lira setup requires Apple Silicon arm64; found ${arch}."
  [[ "${macos_major}" =~ ^[0-9]+$ ]] || fail "Could not parse macOS version: ${macos_version}."
  (( macos_major >= MIN_MACOS_MAJOR )) || fail "Lira setup requires macOS ${MIN_MACOS_MAJOR}.0 or newer; found ${macos_version}."

  printf 'macOS %s on %s OK\n' "${macos_version}" "${arch}"
}

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    brew --version | head -n 1
    return
  fi

  printf 'Homebrew not found. Installing Homebrew non-interactively...\n'
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x "${BREW_PREFIX}/bin/brew" ]]; then
    eval "$("${BREW_PREFIX}/bin/brew" shellenv)"
  fi

  command -v brew >/dev/null 2>&1 || fail "Homebrew installation completed but brew is still not on PATH."
  brew --version | head -n 1
}

ensure_python311() {
  brew list python@3.11 >/dev/null 2>&1 || brew install python@3.11

  local python_bin
  python_bin="$(brew --prefix python@3.11)/bin/python3.11"
  [[ -x "${python_bin}" ]] || fail "python@3.11 was installed but ${python_bin} is missing or not executable."
  "${python_bin}" --version
}

create_main_venv() {
  local python_bin
  python_bin="$(brew --prefix python@3.11)/bin/python3.11"
  [[ -f "${MAIN_REQUIREMENTS}" ]] || fail "Main requirements file missing: ${MAIN_REQUIREMENTS}"

  "${python_bin}" -m venv "${MAIN_VENV}"
  "${MAIN_VENV}/bin/python" -m pip install --upgrade pip setuptools wheel
  "${MAIN_VENV}/bin/python" -m pip install -r "${MAIN_REQUIREMENTS}"
}

create_bonsai_venv() {
  local python_bin
  python_bin="$(brew --prefix python@3.11)/bin/python3.11"
  [[ -f "${BONSAI_REQUIREMENTS}" ]] || fail "Bonsai requirements file missing: ${BONSAI_REQUIREMENTS}"

  "${python_bin}" -m venv "${BONSAI_VENV}"
  "${BONSAI_VENV}/bin/python" -m pip install --upgrade pip setuptools wheel
  "${BONSAI_VENV}/bin/python" -m pip install -r "${BONSAI_REQUIREMENTS}"
}

install_playwright_chromium() {
  "${MAIN_VENV}/bin/python" -m playwright install chromium
}

main() {
  cd "${ROOT_DIR}"
  export PATH="${BREW_PREFIX}/bin:${BREW_PREFIX}/sbin:${PATH}"

  run "check macOS arm64" ensure_macos_arm64
  run "ensure Homebrew" ensure_homebrew
  run "ensure python@3.11" ensure_python311
  run "create .venv and install main deps" create_main_venv
  run "create .venv-bonsai and install GGUF sidecar deps" create_bonsai_venv
  run "install Playwright Chromium" install_playwright_chromium

  printf '\nSUCCESS: Lira dev environment is ready.\n'
  printf 'Main venv: %s\n' "${MAIN_VENV}"
  printf 'Bonsai venv: %s\n' "${BONSAI_VENV}"
  printf 'Bonsai backend: GGUF fallback from bonsai_sidecar/requirements.txt\n'
}

main "$@"
