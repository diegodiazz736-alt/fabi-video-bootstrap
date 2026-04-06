#!/usr/bin/env bash

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/diegodiazz736-alt/fabi-video-bootstrap.git}"
REPO_DIR="${REPO_DIR:-$HOME/fabi-video-bootstrap}"
BOOTSTRAP_SCRIPT="${BOOTSTRAP_SCRIPT:-$REPO_DIR/bootstrap_comfy_wan22.sh}"
MODEL_PRESET="${MODEL_PRESET:-a14b_i2v}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

have_sudo() {
  command -v sudo >/dev/null 2>&1
}

run_privileged() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif have_sudo; then
    sudo "$@"
  else
    echo "Need root or sudo to install system packages." >&2
    exit 1
  fi
}

install_system_packages() {
  if command -v apt-get >/dev/null 2>&1; then
    log "Installing Ubuntu or Debian system packages"
    run_privileged apt-get update
    run_privileged apt-get install -y \
      git curl ca-certificates build-essential pkg-config \
      "$PYTHON_BIN" "${PYTHON_BIN}-venv"
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    log "Installing Fedora or RHEL system packages"
    run_privileged dnf install -y \
      git curl ca-certificates gcc gcc-c++ make pkgconf-pkg-config \
      "$PYTHON_BIN"
    return
  fi

  echo "Unsupported package manager. Install git, curl, build tools, $PYTHON_BIN and ${PYTHON_BIN}-venv manually." >&2
  exit 1
}

clone_or_update_repo() {
  if [[ ! -d "$REPO_DIR/.git" ]]; then
    log "Cloning fabi-video-bootstrap"
    git clone "$REPO_URL" "$REPO_DIR"
    return
  fi

  log "Updating fabi-video-bootstrap"
  git -C "$REPO_DIR" fetch --all --tags
  git -C "$REPO_DIR" pull --ff-only
}

main() {
  install_system_packages
  clone_or_update_repo

  log "Running Wan 2.2 + ComfyUI bootstrap"
  chmod +x "$BOOTSTRAP_SCRIPT"
  MODEL_PRESET="$MODEL_PRESET" "$BOOTSTRAP_SCRIPT"

  log "Fresh-machine install complete"
  printf 'Next step: %s\n' "$HOME/comfy-wan-local/run-comfyui.sh"
}

main "$@"
