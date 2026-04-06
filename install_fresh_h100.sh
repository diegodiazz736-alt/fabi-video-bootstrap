#!/usr/bin/env bash

set -euo pipefail

# One-shot installer for a fresh Linux GPU machine.
# It installs minimal system dependencies, clones this repo locally,
# and runs the SkyReels bootstrap.

REPO_URL="${REPO_URL:-https://github.com/diegodiazz736-alt/fabi-video-bootstrap.git}"
CHECKOUT_DIR="${CHECKOUT_DIR:-$HOME/fabi-video-bootstrap}"
BOOTSTRAP_SCRIPT="${BOOTSTRAP_SCRIPT:-bootstrap_skyreels_v3.sh}"
RUN_BOOTSTRAP="${RUN_BOOTSTRAP:-1}"
SUDO=""

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

install_system_packages() {
  if command -v apt-get >/dev/null 2>&1; then
    log "Installing system packages with apt"
    $SUDO apt-get update
    $SUDO apt-get install -y \
      git \
      curl \
      wget \
      python3 \
      python3-venv \
      python3-pip \
      ffmpeg
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    log "Installing system packages with dnf"
    $SUDO dnf install -y \
      git \
      curl \
      wget \
      python3 \
      python3-pip \
      ffmpeg
    return
  fi

  echo "Unsupported package manager. Install git, curl, python3, python3-venv, python3-pip, and ffmpeg manually." >&2
  exit 1
}

clone_or_update_repo() {
  if [[ ! -d "$CHECKOUT_DIR/.git" ]]; then
    log "Cloning fabi-video-bootstrap"
    git clone "$REPO_URL" "$CHECKOUT_DIR"
  else
    log "Updating existing checkout"
    git -C "$CHECKOUT_DIR" pull --ff-only
  fi
}

run_bootstrap() {
  local script_path="$CHECKOUT_DIR/$BOOTSTRAP_SCRIPT"
  if [[ ! -f "$script_path" ]]; then
    echo "Bootstrap script not found: $script_path" >&2
    exit 1
  fi

  chmod +x "$script_path"
  log "Running $BOOTSTRAP_SCRIPT"
  "$script_path"
}

usage() {
  cat <<EOF
Usage:
  ./install_fresh_h100.sh

Optional environment variables:
  REPO_URL         Default: $REPO_URL
  CHECKOUT_DIR     Default: $CHECKOUT_DIR
  BOOTSTRAP_SCRIPT Default: $BOOTSTRAP_SCRIPT
  RUN_BOOTSTRAP    Default: 1

This script is intended for a fresh Linux GPU machine and installs:
  git curl wget python3 python3-venv python3-pip ffmpeg
EOF
}

main() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
  fi

  if [[ "$EUID" -ne 0 ]]; then
    need_cmd sudo
    SUDO="sudo"
  fi

  install_system_packages
  need_cmd git
  need_cmd curl
  need_cmd python3

  clone_or_update_repo

  if [[ "$RUN_BOOTSTRAP" == "1" ]]; then
    run_bootstrap
  else
    log "Skipping bootstrap because RUN_BOOTSTRAP=$RUN_BOOTSTRAP"
  fi

  log "Fresh-machine install complete"
  printf 'Checkout: %s\n' "$CHECKOUT_DIR"
}

main "$@"
