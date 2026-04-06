#!/usr/bin/env bash

set -euo pipefail

# Convenience wrapper around a local SkyReels V3 install.
# Override INSTALL_ROOT if your remote box uses a different location.

INSTALL_ROOT="${INSTALL_ROOT:-$HOME/skyreels-local}"
REPO_DIR="${REPO_DIR:-$INSTALL_ROOT/SkyReels-V3}"
VENV_DIR="${VENV_DIR:-$INSTALL_ROOT/venv}"
MODEL_DIR="${MODEL_DIR:-$INSTALL_ROOT/models/SkyReels-V3-R2V-14B}"

usage() {
  cat <<EOF
Usage:
  REF_IMGS="/abs/a.png,/abs/b.png" PROMPT="..." ./run_skyreels_r2v.sh

Optional environment variables:
  RESOLUTION=720P
  DURATION=5
  SEED=42
  OFFLOAD=1
  LOW_VRAM=0
  EXTRA_ARGS="..."

Notes:
  - REF_IMGS must contain 1 to 4 comma-separated local paths.
  - Generated videos land in:
      \$REPO_DIR/result/reference_to_video/
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ -z "${REF_IMGS:-}" ]]; then
  echo "REF_IMGS is required" >&2
  usage
  exit 1
fi

if [[ -z "${PROMPT:-}" ]]; then
  echo "PROMPT is required" >&2
  usage
  exit 1
fi

RESOLUTION="${RESOLUTION:-720P}"
DURATION="${DURATION:-5}"
SEED="${SEED:-42}"
OFFLOAD="${OFFLOAD:-1}"
LOW_VRAM="${LOW_VRAM:-0}"
EXTRA_ARGS="${EXTRA_ARGS:-}"

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
cd "$REPO_DIR"

cmd=(
  python3 generate_video.py
  --task_type reference_to_video
  --model_id "$MODEL_DIR"
  --ref_imgs "$REF_IMGS"
  --prompt "$PROMPT"
  --duration "$DURATION"
  --resolution "$RESOLUTION"
  --seed "$SEED"
)

if [[ "$OFFLOAD" == "1" ]]; then
  cmd+=(--offload)
fi

if [[ "$LOW_VRAM" == "1" ]]; then
  cmd+=(--low_vram)
fi

if [[ -n "$EXTRA_ARGS" ]]; then
  # shellcheck disable=SC2206
  extra_parts=($EXTRA_ARGS)
  cmd+=("${extra_parts[@]}")
fi

printf 'Running: '
printf '%q ' "${cmd[@]}"
printf '\n'

"${cmd[@]}"
