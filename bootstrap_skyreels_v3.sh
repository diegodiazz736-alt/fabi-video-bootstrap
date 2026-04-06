#!/usr/bin/env bash

set -euo pipefail

# Fresh-machine bootstrap for local-only SkyReels V3 reference-to-video on Linux.
# Tuned for a single H100 and multi-reference identity-preserving generation.

INSTALL_ROOT="${INSTALL_ROOT:-$HOME/skyreels-local}"
REPO_DIR="${REPO_DIR:-$INSTALL_ROOT/SkyReels-V3}"
VENV_DIR="${VENV_DIR:-$INSTALL_ROOT/venv}"
MODEL_DIR="${MODEL_DIR:-$INSTALL_ROOT/models/SkyReels-V3-R2V-14B}"
INPUT_DIR="${INPUT_DIR:-$INSTALL_ROOT/inputs}"
OUTPUT_DIR="${OUTPUT_DIR:-$INSTALL_ROOT/outputs}"
PROMPT_DIR="${PROMPT_DIR:-$INSTALL_ROOT/prompts}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
HF_BIN="${HF_BIN:-}"
TORCH_INDEX_URL="${TORCH_INDEX_URL:-https://download.pytorch.org/whl/cu128}"
SKYREELS_REPO="${SKYREELS_REPO:-https://github.com/SkyworkAI/SkyReels-V3.git}"
SKYREELS_REF="${SKYREELS_REF:-main}"
SKYREELS_MODEL_ID="${SKYREELS_MODEL_ID:-Skywork/SkyReels-V3-R2V-14B}"
PRELOAD_MODEL="${PRELOAD_MODEL:-1}"
TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-9.0}"

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

ensure_dir() {
  mkdir -p "$1"
}

resolve_hf_bin() {
  if [[ -n "$HF_BIN" ]] && command -v "$HF_BIN" >/dev/null 2>&1; then
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

  echo "Unable to find a Hugging Face CLI command (expected 'hf' or 'huggingface-cli')." >&2
  exit 1
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
  pip install --upgrade pip setuptools wheel packaging ninja

  log "Installing CUDA PyTorch wheels"
  pip install --upgrade \
    torch==2.8.0 \
    torchvision==0.23.0 \
    --index-url "$TORCH_INDEX_URL"

  log "Installing Hugging Face CLI"
  pip install --upgrade "huggingface_hub[cli]"

  log "Installing media runtime dependencies used by SkyReels"
  pip install --upgrade av
}

bootstrap_repo() {
  local requirements_file="$REPO_DIR/requirements.txt"
  local filtered_requirements="$INSTALL_ROOT/requirements.no_flash_attn.txt"
  local flash_attn_spec=""

  log "Installing SkyReels V3 repository"
  if [[ ! -d "$REPO_DIR/.git" ]]; then
    git clone "$SKYREELS_REPO" "$REPO_DIR"
  fi

  git -C "$REPO_DIR" fetch --all --tags
  git -C "$REPO_DIR" checkout "$SKYREELS_REF"
  git -C "$REPO_DIR" pull --ff-only

  log "Patching SkyReels CLI for negative prompt support"
  "$PYTHON_BIN" - <<'PY' "$REPO_DIR/generate_video.py"
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

arg_block = """    parser.add_argument(
        "--negative_prompt",
        type=str,
        default="",
        help="[reference_to_video] Negative prompt describing what to avoid in the generated video.",
    )
"""

marker = """    parser.add_argument(
        "--resolution",
"""

call_old = """        video_out = pipe.generate_video(args.ref_imgs, args.prompt, args.duration, args.seed, resolution=args.resolution)
"""

call_new = """        video_out = pipe.generate_video(
            args.ref_imgs,
            args.prompt,
            args.duration,
            args.seed,
            resolution=args.resolution,
            negative_prompt=args.negative_prompt,
        )
"""

changed = False
if "--negative_prompt" not in text:
    if marker not in text:
        raise SystemExit("Could not find resolution argument marker in generate_video.py")
    text = text.replace(marker, arg_block + marker, 1)
    changed = True

if call_old in text:
    text = text.replace(call_old, call_new, 1)
    changed = True
elif "negative_prompt=args.negative_prompt" not in text:
    raise SystemExit("Could not find reference_to_video generate_video call in generate_video.py")

if changed:
    path.write_text(text)
PY

  log "Patching SkyReels reference pipeline for negative prompt support"
  "$PYTHON_BIN" - <<'PY' "$REPO_DIR/skyreels_v3/pipelines/reference_to_video_pipeline.py"
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

sig_old = '    def generate_video(self, ref_imgs, prompt, duration, seed, resolution="720P"):\n'
sig_new = '    def generate_video(self, ref_imgs, prompt, duration, seed, resolution="720P", negative_prompt=""):\n'

if sig_old in text:
    text = text.replace(sig_old, sig_new, 1)

kwargs_old = '            "negative_prompt": "",\n'
kwargs_new = '            "negative_prompt": negative_prompt,\n'

if kwargs_old in text:
    text = text.replace(kwargs_old, kwargs_new, 1)

path.write_text(text)
PY

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  export TORCH_CUDA_ARCH_LIST

  log "Installing SkyReels Python requirements"
  flash_attn_spec="$(grep -E '^flash_attn([=<>!~].*)?$' "$requirements_file" | head -n 1 || true)"
  if [[ -n "$flash_attn_spec" ]]; then
    grep -Ev '^flash_attn([=<>!~].*)?$' "$requirements_file" >"$filtered_requirements"
    pip install -r "$filtered_requirements"
    log "Installing flash_attn without build isolation"
    pip install --no-build-isolation "$flash_attn_spec"
  else
    pip install -r "$requirements_file"
  fi
}

download_model() {
  if [[ "$PRELOAD_MODEL" != "1" ]]; then
    log "Skipping model preload because PRELOAD_MODEL=$PRELOAD_MODEL"
    return
  fi

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  log "Preloading local SkyReels R2V model weights"
  ensure_dir "$MODEL_DIR"
  "$HF_BIN" download "$SKYREELS_MODEL_ID" --local-dir "$MODEL_DIR"
}

write_runner() {
  local runner="$INSTALL_ROOT/run-skyreels-r2v.sh"
  log "Writing reference-to-video runner"
  cat >"$runner" <<EOF
#!/usr/bin/env bash
set -euo pipefail

INSTALL_ROOT="${INSTALL_ROOT}"
REPO_DIR="${REPO_DIR}"
VENV_DIR="${VENV_DIR}"
MODEL_DIR="${MODEL_DIR}"
OUTPUT_DIR="${OUTPUT_DIR}"

usage() {
  cat <<USAGE
Usage:
  REF_IMGS="/abs/a.png,/abs/b.png" PROMPT="..." $runner

Optional environment variables:
  RESOLUTION=720P
  DURATION=5
  SEED=42
  NEGATIVE_PROMPT="..."
  OFFLOAD=1
  LOW_VRAM=0
  EXTRA_ARGS="..."

Notes:
  - REF_IMGS must contain 1 to 4 comma-separated local image paths.
  - Results are written by SkyReels under:
      \$REPO_DIR/result/reference_to_video/
USAGE
}

if [[ "\${1:-}" == "--help" || "\${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ -z "\${REF_IMGS:-}" ]]; then
  echo "REF_IMGS is required" >&2
  usage
  exit 1
fi

if [[ -z "\${PROMPT:-}" ]]; then
  echo "PROMPT is required" >&2
  usage
  exit 1
fi

RESOLUTION="\${RESOLUTION:-720P}"
DURATION="\${DURATION:-5}"
SEED="\${SEED:-42}"
NEGATIVE_PROMPT="\${NEGATIVE_PROMPT:-}"
OFFLOAD="\${OFFLOAD:-1}"
LOW_VRAM="\${LOW_VRAM:-0}"
EXTRA_ARGS="\${EXTRA_ARGS:-}"

mkdir -p "\$OUTPUT_DIR"

# shellcheck disable=SC1091
source "\$VENV_DIR/bin/activate"
cd "\$REPO_DIR"

cmd=(
  python3 generate_video.py
  --task_type reference_to_video
  --model_id "\$MODEL_DIR"
  --ref_imgs "\$REF_IMGS"
  --prompt "\$PROMPT"
  --duration "\$DURATION"
  --resolution "\$RESOLUTION"
  --seed "\$SEED"
)

if [[ -n "\$NEGATIVE_PROMPT" ]]; then
  cmd+=(--negative_prompt "\$NEGATIVE_PROMPT")
fi

if [[ "\$OFFLOAD" == "1" ]]; then
  cmd+=(--offload)
fi

if [[ "\$LOW_VRAM" == "1" ]]; then
  cmd+=(--low_vram)
fi

if [[ -n "\$EXTRA_ARGS" ]]; then
  # shellcheck disable=SC2206
  extra_parts=(\$EXTRA_ARGS)
  cmd+=("\${extra_parts[@]}")
fi

printf 'Running: '
printf '%q ' "\${cmd[@]}"
printf '\n'

"\${cmd[@]}"
EOF
  chmod +x "$runner"
}

write_prompt_template() {
  local prompt_file="$PROMPT_DIR/identity_first_prompt_template.txt"
  log "Writing prompt template"
  ensure_dir "$PROMPT_DIR"
  cat >"$prompt_file" <<'EOF'
[subject anchor carried by the reference images],
[framing and lens feel],
the subject [small, specific motion],
facial behavior: [micro-expression, eye line, blink behavior],
camera motion: [slow push in / static / gentle pan],
environmental motion: [wind, cloth, hair, rain, reflections],
lighting and mood: [cinematic lighting, tone, atmosphere],
high subject consistency, stable facial identity, coherent anatomy, natural motion
EOF
}

write_notes() {
  local notes="$INSTALL_ROOT/START_HERE.txt"
  log "Writing quick-start notes"
  cat >"$notes" <<EOF
SkyReels V3 local bootstrap complete.

Install root:
  $INSTALL_ROOT

Repository:
  $REPO_DIR

Model path:
  $MODEL_DIR

Runner:
  $INSTALL_ROOT/run-skyreels-r2v.sh

Prompt template:
  $PROMPT_DIR/identity_first_prompt_template.txt

Recommended first run on a single H100:
  REF_IMGS="$INPUT_DIR/face_front.png,$INPUT_DIR/face_three_quarter.png,$INPUT_DIR/profile.png" \\
  PROMPT="A cinematic close portrait. The subject makes a slight head turn and breathes naturally. Slow dolly in. Stable facial identity, natural micro-expressions, soft ambient motion." \\
  NEGATIVE_PROMPT="blurry face, inconsistent identity, distorted anatomy, extra limbs, deformed hands, low detail" \\
  $INSTALL_ROOT/run-skyreels-r2v.sh

Official model recommendation:
  5 seconds, 720P, 24 fps

Results are written by SkyReels under:
  $REPO_DIR/result/reference_to_video/
EOF
}

usage() {
  cat <<EOF
Usage:
  PRELOAD_MODEL=1 ./bootstrap_skyreels_v3.sh

Optional environment variables:
  INSTALL_ROOT      Default: \$HOME/skyreels-local
  SKYREELS_REF      Default: main
  SKYREELS_MODEL_ID Default: Skywork/SkyReels-V3-R2V-14B
  PRELOAD_MODEL     Default: 1
  PYTHON_BIN        Default: python3
  TORCH_INDEX_URL   Default: https://download.pytorch.org/whl/cu128
  TORCH_CUDA_ARCH_LIST Default: 9.0

If your Hugging Face environment requires auth:
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
  need_cmd "$PYTHON_BIN"

  ensure_dir "$INPUT_DIR"
  ensure_dir "$OUTPUT_DIR"

  bootstrap_python
  resolve_hf_bin
  bootstrap_repo
  download_model
  write_runner
  write_prompt_template
  write_notes

  log "All done"
  printf 'Installed under: %s\n' "$INSTALL_ROOT"
}

main "$@"
