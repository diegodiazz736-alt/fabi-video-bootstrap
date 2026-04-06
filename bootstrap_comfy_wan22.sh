#!/usr/bin/env bash

set -euo pipefail

# Fresh-machine bootstrap for ComfyUI + Wan 2.2 video workflows on Linux.
# Defaults are tuned for an H100 box doing image-to-video and first/last-frame
# generation, with a lighter TI2V path available for faster iteration.

INSTALL_ROOT="${INSTALL_ROOT:-$HOME/comfy-wan-local}"
COMFY_DIR="${COMFY_DIR:-$INSTALL_ROOT/ComfyUI}"
VENV_DIR="${VENV_DIR:-$INSTALL_ROOT/venv}"
WORKFLOW_DIR="${WORKFLOW_DIR:-$INSTALL_ROOT/workflows/wan22}"
MODEL_CACHE_DIR="${MODEL_CACHE_DIR:-$INSTALL_ROOT/model_cache}"
MODEL_PRESET="${MODEL_PRESET:-a14b_i2v}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
TORCH_INDEX_URL="${TORCH_INDEX_URL:-https://download.pytorch.org/whl/cu124}"
HF_BIN="${HF_BIN:-}"
COMFYUI_REF="${COMFYUI_REF:-master}"
COMFYUI_REPO="${COMFYUI_REPO:-https://github.com/comfyanonymous/ComfyUI.git}"
MANAGER_REPO="${MANAGER_REPO:-https://github.com/Comfy-Org/ComfyUI-Manager.git}"
COMFY_PORT="${COMFY_PORT:-8188}"
COMFY_HOST="${COMFY_HOST:-0.0.0.0}"

WAN22_REPACKAGED_REPO="Comfy-Org/Wan_2.2_ComfyUI_Repackaged"
WAN21_REPACKAGED_REPO="Comfy-Org/Wan_2.1_ComfyUI_repackaged"

WORKFLOW_5B_TI2V_URL="https://raw.githubusercontent.com/Comfy-Org/workflow_templates/refs/heads/main/templates/video_wan2_2_5B_ti2v.json"
WORKFLOW_14B_I2V_URL="https://raw.githubusercontent.com/Comfy-Org/workflow_templates/refs/heads/main/templates/video_wan2_2_14B_i2v.json"
WORKFLOW_14B_T2V_URL="https://raw.githubusercontent.com/Comfy-Org/workflow_templates/refs/heads/main/templates/video_wan2_2_14B_t2v.json"
WORKFLOW_14B_FLF2V_URL="https://raw.githubusercontent.com/Comfy-Org/workflow_templates/refs/heads/main/templates/video_wan2_2_14B_flf2v.json"

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

resolve_hf_cli() {
  if [[ -n "$HF_BIN" ]]; then
    need_cmd "$HF_BIN"
    return
  fi

  if command -v hf >/dev/null 2>&1; then
    HF_BIN="hf"
    return
  fi

  if command -v huggingface-cli >/dev/null 2>&1; then
    HF_BIN="huggingface-cli"
    return
  fi

  echo "Missing Hugging Face CLI. Install huggingface_hub[cli] inside the venv first." >&2
  exit 1
}

ensure_dir() {
  mkdir -p "$1"
}

download_hf_files() {
  local repo="$1"
  local target_dir="$2"
  shift 2
  ensure_dir "$target_dir"
  "$HF_BIN" download "$repo" "$@" --local-dir "$target_dir"
}

install_named_file() {
  local source_root="$1"
  local filename="$2"
  local dest_dir="$3"
  local found

  ensure_dir "$dest_dir"
  found="$(find "$source_root" -type f -name "$filename" | head -n 1 || true)"
  if [[ -z "$found" ]]; then
    echo "Unable to find downloaded file: $filename in $source_root" >&2
    exit 1
  fi

  cp -f "$found" "$dest_dir/$filename"
}

download_workflow() {
  local url="$1"
  local dest="$2"
  curl -L --fail --retry 5 --retry-delay 2 -o "$dest" "$url"
}

bootstrap_python() {
  log "Creating Python virtual environment"
  ensure_dir "$INSTALL_ROOT"
  if [[ ! -d "$VENV_DIR" ]]; then
    "$PYTHON_BIN" -m venv "$VENV_DIR"
  fi

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  log "Upgrading pip toolchain"
  pip install --upgrade pip setuptools wheel

  log "Installing PyTorch with CUDA support"
  pip install --upgrade torch torchvision torchaudio --index-url "$TORCH_INDEX_URL"

  log "Installing bootstrap helpers"
  pip install --upgrade huggingface_hub[cli] ninja safetensors sentencepiece

  resolve_hf_cli
}

bootstrap_comfyui() {
  log "Installing ComfyUI"
  if [[ ! -d "$COMFY_DIR/.git" ]]; then
    git clone "$COMFYUI_REPO" "$COMFY_DIR"
  fi

  git -C "$COMFY_DIR" fetch --all --tags
  git -C "$COMFY_DIR" checkout "$COMFYUI_REF"
  git -C "$COMFY_DIR" pull --ff-only

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  log "Installing ComfyUI Python requirements"
  pip install -r "$COMFY_DIR/requirements.txt"

  log "Installing ComfyUI-Manager"
  if [[ ! -d "$COMFY_DIR/custom_nodes/ComfyUI-Manager/.git" ]]; then
    git clone "$MANAGER_REPO" "$COMFY_DIR/custom_nodes/ComfyUI-Manager"
  else
    git -C "$COMFY_DIR/custom_nodes/ComfyUI-Manager" pull --ff-only
  fi

  if [[ -f "$COMFY_DIR/custom_nodes/ComfyUI-Manager/requirements.txt" ]]; then
    pip install -r "$COMFY_DIR/custom_nodes/ComfyUI-Manager/requirements.txt"
  fi
}

download_common_models() {
  local temp_dir="$MODEL_CACHE_DIR/common"
  log "Downloading shared Wan text encoder and VAE files"

  download_hf_files "$WAN21_REPACKAGED_REPO" "$temp_dir" \
    split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors

  download_hf_files "$WAN22_REPACKAGED_REPO" "$temp_dir" \
    split_files/vae/wan_2.1_vae.safetensors \
    split_files/vae/wan2.2_vae.safetensors

  install_named_file "$temp_dir" "umt5_xxl_fp8_e4m3fn_scaled.safetensors" "$COMFY_DIR/models/text_encoders"
  install_named_file "$temp_dir" "wan_2.1_vae.safetensors" "$COMFY_DIR/models/vae"
  install_named_file "$temp_dir" "wan2.2_vae.safetensors" "$COMFY_DIR/models/vae"
}

download_a14b_i2v_models() {
  local temp_dir="$MODEL_CACHE_DIR/a14b_i2v"
  log "Downloading Wan 2.2 A14B image-to-video models"

  download_hf_files "$WAN22_REPACKAGED_REPO" "$temp_dir" \
    split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp16.safetensors \
    split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp16.safetensors

  install_named_file "$temp_dir" "wan2.2_i2v_high_noise_14B_fp16.safetensors" "$COMFY_DIR/models/diffusion_models"
  install_named_file "$temp_dir" "wan2.2_i2v_low_noise_14B_fp16.safetensors" "$COMFY_DIR/models/diffusion_models"
}

download_ti2v_5b_models() {
  local temp_dir="$MODEL_CACHE_DIR/ti2v_5b"
  log "Downloading Wan 2.2 5B TI2V model"

  download_hf_files "$WAN22_REPACKAGED_REPO" "$temp_dir" \
    split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors

  install_named_file "$temp_dir" "wan2.2_ti2v_5B_fp16.safetensors" "$COMFY_DIR/models/diffusion_models"
}

download_t2v_a14b_models() {
  local temp_dir="$MODEL_CACHE_DIR/a14b_t2v"
  log "Downloading Wan 2.2 A14B text-to-video models"

  download_hf_files "$WAN22_REPACKAGED_REPO" "$temp_dir" \
    split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors \
    split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors

  install_named_file "$temp_dir" "wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" "$COMFY_DIR/models/diffusion_models"
  install_named_file "$temp_dir" "wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors" "$COMFY_DIR/models/diffusion_models"
}

download_workflows() {
  log "Downloading official ComfyUI Wan 2.2 workflow templates"
  ensure_dir "$WORKFLOW_DIR"

  download_workflow "$WORKFLOW_14B_I2V_URL" "$WORKFLOW_DIR/wan22_14b_i2v_official.json"
  download_workflow "$WORKFLOW_5B_TI2V_URL" "$WORKFLOW_DIR/wan22_5b_ti2v_official.json"
  download_workflow "$WORKFLOW_14B_T2V_URL" "$WORKFLOW_DIR/wan22_14b_t2v_official.json"
  download_workflow "$WORKFLOW_14B_FLF2V_URL" "$WORKFLOW_DIR/wan22_14b_flf2v_official.json"
}

write_launcher() {
  local launcher="$INSTALL_ROOT/run-comfyui.sh"
  log "Writing ComfyUI launcher"
  cat >"$launcher" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "$VENV_DIR/bin/activate"
cd "$COMFY_DIR"
exec python main.py --listen "$COMFY_HOST" --port "$COMFY_PORT"
EOF
  chmod +x "$launcher"
}

write_notes() {
  local notes="$INSTALL_ROOT/START_HERE.txt"
  log "Writing quick-start notes"
  cat >"$notes" <<EOF
ComfyUI bootstrap complete.

Launcher:
  $INSTALL_ROOT/run-comfyui.sh

ComfyUI URL after launch:
  http://SERVER_IP:$COMFY_PORT

Official workflow JSON files:
  $WORKFLOW_DIR/wan22_14b_i2v_official.json
  $WORKFLOW_DIR/wan22_5b_ti2v_official.json
  $WORKFLOW_DIR/wan22_14b_t2v_official.json
  $WORKFLOW_DIR/wan22_14b_flf2v_official.json

Recommended starting points on an H100:
  Open wan22_14b_i2v_official.json
  Use it when you want the input image to anchor the opening frame
  Keep motion prompts specific and restrained for better coherence

  Open wan22_14b_flf2v_official.json
  Use it when you want explicit first-frame and last-frame control
  The FLF2V workflow uses the same 14B I2V model files already installed here

Fallback / faster path:
  Open wan22_5b_ti2v_official.json
  Use it when you want faster iteration or lower VRAM pressure

Suggested first browser workflow:
  1. Start ComfyUI with $INSTALL_ROOT/run-comfyui.sh
  2. Open the 14B I2V workflow
  3. Upload a single strong source image
  4. Set conservative motion and short duration first
  5. Move to FLF2V once you want start/end frame control
EOF
}

usage() {
  cat <<EOF
Usage:
  MODEL_PRESET=a14b_i2v ./bootstrap_comfy_wan22.sh

Supported MODEL_PRESET values:
  a14b_i2v   Install the best starting point for H100 image-to-video work
  ti2v_5b    Install the lighter hybrid text/image-to-video model
  full       Install both presets plus the A14B text-to-video pair

Optional environment variables:
  INSTALL_ROOT   Default: \$HOME/comfy-wan-local
  COMFYUI_REF    Default: master
  PYTHON_BIN     Default: python3
  TORCH_INDEX_URL Default: https://download.pytorch.org/whl/cu124
  COMFY_PORT     Default: 8188
  HF_BIN         Default: auto-detect hf or huggingface-cli

If the Hugging Face repo requires auth in your environment:
  export HF_TOKEN=...
  hf auth login
EOF
}

main() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
  fi

  need_cmd git
  need_cmd curl
  need_cmd find
  need_cmd "$PYTHON_BIN"

  bootstrap_python
  bootstrap_comfyui
  download_common_models
  download_workflows

  case "$MODEL_PRESET" in
    a14b_i2v)
      download_a14b_i2v_models
      ;;
    ti2v_5b)
      download_ti2v_5b_models
      ;;
    full)
      download_a14b_i2v_models
      download_ti2v_5b_models
      download_t2v_a14b_models
      ;;
    *)
      echo "Unsupported MODEL_PRESET: $MODEL_PRESET" >&2
      usage
      exit 1
      ;;
  esac

  write_launcher
  write_notes

  log "All done"
  printf 'Installed under: %s\n' "$INSTALL_ROOT"
}

main "$@"
