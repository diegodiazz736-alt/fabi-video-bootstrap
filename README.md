# Fabi Video Generation Bootstrap

Local-first bootstrap scripts and notes for running image-to-video workflows on cloud GPUs, with the current main path focused on **ComfyUI + Wan 2.2** for controlled image-to-video and first/last-frame generation.

## Included

- `install_fresh_wan_comfyui.sh`
  - One-shot fresh-machine installer for the current recommended stack: ComfyUI + Wan 2.2.
- `bootstrap_comfy_wan22.sh`
  - Installs ComfyUI, ComfyUI-Manager, official Wan 2.2 workflow JSONs, the 14B I2V and FLF2V model files, and the LightX2V LoRAs used by the common starter I2V template.
  - Can optionally add `WanVideoWrapper`, the official `Stand-In` preprocessor, Wan 2.2 Stand-In weights, and community NSFW LoRAs.
- `wan22-comfyui-notes.md`
  - Practical notes for controlled Wan 2.2 usage on an H100, especially I2V and first/last-frame work.
- `bootstrap_skyreels_v3.sh`
  - Installs the official SkyReels V3 repo and local `SkyReels-V3-R2V-14B` model for multi-reference reference-to-video generation.
- `run_skyreels_r2v.sh`
  - Small helper wrapper for running local SkyReels reference-to-video jobs.
- `skyreels-r2v-notes.md`
  - Practical operating notes for identity-first SkyReels usage on an H100.

## Recommended Path

For controlled local-first image-to-video and first/last-frame generation, start with Wan 2.2 in ComfyUI:

```bash
curl -fsSL https://raw.githubusercontent.com/diegodiazz736-alt/fabi-video-bootstrap/main/install_fresh_wan_comfyui.sh | bash
```

If you prefer not to pipe to shell:

```bash
git clone https://github.com/diegodiazz736-alt/fabi-video-bootstrap.git
cd fabi-video-bootstrap
./install_fresh_wan_comfyui.sh
```

Then launch ComfyUI:

```bash
$HOME/comfy-wan-local/run-comfyui.sh
```

Then in the browser:

- load `$HOME/comfy-wan-local/workflows/wan22/wan22_14b_i2v_official.json` for classic image-to-video
- load `$HOME/comfy-wan-local/workflows/wan22/wan22_14b_flf2v_official.json` for first/last-frame control
- if a starter template expects fp8-scaled Wan diffusion models, switch its two Wan diffusion dropdowns to the installed fp16 pair instead of downloading extra copies immediately

Optional add-on install:

```bash
INSTALL_WANVIDEO_WRAPPER=true \
INSTALL_STANDIN=true \
INSTALL_NSFW_LORAS=true \
NSFW_LORA_REPO="wiikoo/WAN-LORA" \
NSFW_LORA_FILES="wan2.2/NSFW-22-H-e8.safetensors" \
./install_fresh_wan_comfyui.sh
```

## Secondary Path

SkyReels remains in the repo as a secondary path for multi-reference character experiments, but it is no longer the default recommendation for constrained prompt-following work.

Use it only if you specifically want:

- multi-reference identity guidance
- looser reference-to-video exploration
- a direct CLI path rather than ComfyUI

## Notes

- Everything here is intended for local execution on your own machine or rented GPU instance.
- No external generation APIs are required.
- The Wan 2.2 route is now the primary baseline because it offers official ComfyUI-native I2V and FLF2V workflows.
- On providers with a small root disk and a large secondary volume, `install_fresh_wan_comfyui.sh` now prefers `/ephemeral/comfy-wan-local` and symlinks back to `$HOME/comfy-wan-local`.
- `Stand-In` currently means the `WanVideoWrapper` path plus the official `Stand-In_Preprocessor_ComfyUI` node, not the pure native Wan core nodes.
- Community NSFW LoRAs are not official Wan releases, so they are handled as opt-in extras rather than default dependencies.
