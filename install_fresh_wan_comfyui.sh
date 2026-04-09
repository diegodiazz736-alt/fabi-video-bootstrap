#!/usr/bin/env bash

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/diegodiazz736-alt/fabi-video-bootstrap.git}"
REPO_DIR="${REPO_DIR:-$HOME/fabi-video-bootstrap}"
BOOTSTRAP_SCRIPT="${BOOTSTRAP_SCRIPT:-$REPO_DIR/bootstrap_comfy_wan22.sh}"
MODEL_PRESET="${MODEL_PRESET:-a14b_i2v}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
VISIBLE_INSTALL_ROOT="${VISIBLE_INSTALL_ROOT:-$HOME/comfy-wan-local}"
INSTALL_ROOT="${INSTALL_ROOT:-}"
INSTALL_WANVIDEO_WRAPPER="${INSTALL_WANVIDEO_WRAPPER:-false}"
INSTALL_STANDIN="${INSTALL_STANDIN:-false}"
INSTALL_NSFW_LORAS="${INSTALL_NSFW_LORAS:-false}"
NSFW_LORA_REPO="${NSFW_LORA_REPO:-}"
NSFW_LORA_FILES="${NSFW_LORA_FILES:-}"

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

choose_install_root() {
  if [[ -n "$INSTALL_ROOT" ]]; then
    return
  fi

  if [[ -d /ephemeral ]]; then
    INSTALL_ROOT="/ephemeral/comfy-wan-local"
    log "Using /ephemeral for the heavy ComfyUI + Wan install"
    run_privileged mkdir -p "$INSTALL_ROOT"
    run_privileged chown "$(id -un):$(id -gn)" "$INSTALL_ROOT"
    return
  fi

  INSTALL_ROOT="$VISIBLE_INSTALL_ROOT"
}

ensure_visible_install_link() {
  if [[ "$INSTALL_ROOT" == "$VISIBLE_INSTALL_ROOT" ]]; then
    return
  fi

  if [[ -L "$VISIBLE_INSTALL_ROOT" || ! -e "$VISIBLE_INSTALL_ROOT" ]]; then
    rm -f "$VISIBLE_INSTALL_ROOT"
    ln -s "$INSTALL_ROOT" "$VISIBLE_INSTALL_ROOT"
    return
  fi

  echo "Visible install path already exists and is not a symlink: $VISIBLE_INSTALL_ROOT" >&2
  echo "Use INSTALL_ROOT=... or remove that path before running again." >&2
  exit 1
}

main() {
  install_system_packages
  clone_or_update_repo
  choose_install_root
  ensure_visible_install_link

  log "Running Wan 2.2 + ComfyUI bootstrap"
  chmod +x "$BOOTSTRAP_SCRIPT"
  INSTALL_ROOT="$INSTALL_ROOT" \
  MODEL_PRESET="$MODEL_PRESET" \
  INSTALL_WANVIDEO_WRAPPER="$INSTALL_WANVIDEO_WRAPPER" \
  INSTALL_STANDIN="$INSTALL_STANDIN" \
  INSTALL_NSFW_LORAS="$INSTALL_NSFW_LORAS" \
  NSFW_LORA_REPO="$NSFW_LORA_REPO" \
  NSFW_LORA_FILES="$NSFW_LORA_FILES" \
  "$BOOTSTRAP_SCRIPT"

  log "Fresh-machine install complete"
  printf 'Next step: %s\n' "$VISIBLE_INSTALL_ROOT/run-comfyui.sh"
}

main "$@"
