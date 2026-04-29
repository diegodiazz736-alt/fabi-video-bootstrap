# Wan 2.2 on an H100 or Blackwell-class box: practical controlled-video starting point

For what you described now, the strongest current starting point is the official **ComfyUI native Wan 2.2 14B I2V** workflow plus the official **Wan 2.2 14B FLF2V** workflow. That gives you both a proper start-frame-driven path and a more constrained first/last-frame path without leaving the local box.

For stronger identity locking from the first frame, there is now also a practical optional path:

- `WanVideoWrapper`
- the official `Stand-In_Preprocessor_ComfyUI`
- Wan 2.2 `Stand-In` weights

That path is more experimental than native Wan and is best treated as an add-on rather than the baseline.

Why this is the right default:

- It is the official ComfyUI image-to-video path for Wan 2.2.
- It also has an official **first-last-frame** workflow in the same ecosystem.
- Wan 2.2 A14B is explicitly positioned for image-to-video and supports **480p and 720p** generation.
- The upstream Wan 2.2 I2V model page shows **1280x720 single-GPU inference on at least 80 GB VRAM**, which lines up well with an H100.
- You keep closer to current ComfyUI core nodes, so fresh-machine rebuilds are less fragile than a deep stack of custom nodes.
- The practical H100 setup benefits from putting the heavy install on a large secondary volume like `/ephemeral` when the provider ships a tiny root disk.
- Newer Blackwell-class GPUs need newer CUDA PyTorch wheels than the older H100-only baseline, so the bootstrap now defaults to `cu128`.

## What to start with

Primary workflow:

- `wan22_14b_i2v_official.json`

Paired control workflow:

- `wan22_14b_flf2v_official.json`

Use this when:

- you have a strong reference image
- you want the input image to act as the practical opening-frame anchor
- you care about prompt-following and constrained motion more than multi-image lottery behavior

Use FLF2V when:

- you want a clear start frame and end frame
- you want the model to solve the transition between known visual endpoints
- you want tighter shot design than pure reference-to-video gives you

Secondary workflow:

- `wan22_5b_ti2v_official.json`

Use this when:

- you want faster iteration
- you want a lighter fallback if the A14B setup is being awkward
- you are doing prompt exploration before moving to the heavier workflow

## Practical recipe

For best coherence from a single reference image:

- Keep the prompt focused on **motion, camera, atmosphere, and secondary action**, not on re-describing every visible detail.
- Use the input image as the visual anchor and let the prompt describe the change over time.
- Ask for restrained movement first: "subtle head turn", "slow dolly in", "gentle wind through fabric", "soft handheld drift".
- Generate short clips first, then chain or upscale later.
- Treat **720p as the native working resolution** and do final enhancement after generation if you need higher delivery resolution.

For FLF2V:

- Make the first and last frame agree on identity, costume, setting, and lens feel.
- Ask the prompt to describe the motion path between the two frames, not to reinvent the whole scene.
- Keep the transition physically plausible at first.
- Use this mode when body shape, facial fidelity, and camera intent need firmer boundaries.

## Suggested prompt shape

Use prompts in this pattern:

```text
[subject and scene anchor from the image],
the camera [camera move],
the subject [specific motion],
environmental motion: [wind, smoke, water, foliage, reflections],
cinematic style: [lighting, lens feel, mood],
temporal qualities: coherent motion, stable anatomy, natural micro-movements
```

Example:

```text
A woman in a red coat standing on a wet nighttime street,
slow dolly in, she lifts her chin and turns slightly toward camera,
soft rain ripples in puddles, neon reflections shimmer on the asphalt,
cinematic low-key lighting, 50mm lens feel, moody urban atmosphere,
coherent motion, stable anatomy, natural facial movement
```

## A note on "high resolution"

On current open workflows, the reliable pattern is usually:

1. generate a coherent native clip first
2. pick the best seed and prompt
3. upscale or enhance after

That is usually more dependable than trying to force the first pass to be "max resolution everything".

## What the bootstrap scripts do

`bootstrap_comfy_wan22.sh` will:

- create a Python venv
- install PyTorch with CUDA wheels, now defaulting to `cu128`
- clone and update ComfyUI
- install ComfyUI-Manager
- download the official Wan 2.2 workflow JSON files
- download the LightX2V LoRAs used by the common Wan starter I2V template
- download the model files needed for either:
  - `MODEL_PRESET=a14b_i2v`
  - `MODEL_PRESET=ti2v_5b`
  - `MODEL_PRESET=full`
- write a `run-comfyui.sh` launcher
- optionally install `WanVideoWrapper`
- optionally install the official `Stand-In_Preprocessor_ComfyUI`
- optionally download Wan 2.2 `Stand-In` weights
- optionally install `ComfyUI_IPAdapter_plus`
- optionally install `insightface` and `onnxruntime`
- optionally download the canonical FaceID assets for the built-in `ipadapter_faceid` template:
  - `CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors`
  - `ip-adapter-faceid-plusv2_sd15.bin`
  - `ip-adapter-faceid-plusv2_sd15_lora.safetensors`
  - `ip-adapter-faceid-plusv2_sdxl.bin`
  - `ip-adapter-faceid-plusv2_sdxl_lora.safetensors`
  - `sd15/realisticVisionV51_v51VAE.safetensors`
- optionally download facial expression LoRAs, defaulting to `wan22-face-naturalizer.safetensors`
- optionally download community NSFW LoRAs you specify via environment variables

`install_fresh_wan_comfyui.sh` will:

- install base system packages on a fresh Linux VM
- clone or update this repo
- prefer `/ephemeral/comfy-wan-local` automatically when that large secondary volume exists
- create a symlink back to `$HOME/comfy-wan-local` so the user-facing paths stay simple
- run the Wan 2.2 ComfyUI bootstrap automatically
- auto-detect `hf` or `huggingface-cli` for model downloads
- pass through optional flags for `WanVideoWrapper`, `Stand-In`, `ComfyUI_IPAdapter_plus`, and community NSFW LoRAs
- pass through optional facial expression LoRA settings

## Recommended first run

```bash
curl -fsSL https://raw.githubusercontent.com/diegodiazz736-alt/fabi-video-bootstrap/main/install_fresh_wan_comfyui.sh | bash
```

Then on the server:

```bash
$HOME/comfy-wan-local/run-comfyui.sh
```

Then in ComfyUI:

- load `$HOME/comfy-wan-local/workflows/wan22/wan22_14b_i2v_official.json`
- upload your reference image
- start around `1280x720`
- keep the first motion prompt simple
- if a starter Wan I2V template defaults to missing fp8-scaled diffusion models, switch the two Wan diffusion dropdowns to:
  - `wan2.2_i2v_high_noise_14B_fp16.safetensors`
  - `wan2.2_i2v_low_noise_14B_fp16.safetensors`

Bundled community still-image identity workflows:

- `$HOME/comfy-wan-local/workflows/community/ip-adapter-faceid-sdxl.json`
- `$HOME/comfy-wan-local/workflows/community/simple-instantid-workflow.json`

Use these when:

- you want to preserve one face strongly in a new still-image scene
- you are experimenting with identity transfer before moving back to video
- you want a ready-made community graph rather than starting from a blank canvas

Current recommendation for still-image identity preservation:

- install with `INSTALL_IPADAPTER_FACEID=true`
- in ComfyUI, use the built-in template browser and open `ipadapter_faceid`
- prefer that built-in template over the older bundled community FaceID JSONs

Why:

- `ComfyUI_IPAdapter_plus` changed substantially, and older community FaceID graphs can use stale node definitions
- the built-in template tracks the currently installed extension much more reliably
- the built-in template is the path that was actually verified to work on the cloud box

For first/last frame work:

- load `$HOME/comfy-wan-local/workflows/wan22/wan22_14b_flf2v_official.json`
- upload a start image and an end image
- start at conservative resolution and short duration
- use prompt text to describe the transition, not unrelated scene changes

## Optional add-ons

Stand-In path:

- install with `INSTALL_WANVIDEO_WRAPPER=true INSTALL_STANDIN=true`
- this adds the custom node stack needed for current ComfyUI Stand-In usage
- it also pulls the Wan 2.2 Stand-In weights from `Kijai/WanVideo_comfy`
- the official Stand-In team currently recommends using their preprocessor node inside ComfyUI for better results than the wrapper-only preprocessing

Community NSFW LoRAs:

- install with `INSTALL_NSFW_LORAS=true`
- specify:
  - `NSFW_LORA_REPO`
  - `NSFW_LORA_FILES`
- example:

```bash
INSTALL_NSFW_LORAS=true \
NSFW_LORA_REPO="wiikoo/WAN-LORA" \
NSFW_LORA_FILES="wan2.2/NSFW-22-H-e8.safetensors" \
./install_fresh_wan_comfyui.sh
```

Treat these as experimental community add-ons, not official Wan components.

Facial expression LoRAs:

- install with `INSTALL_EXPRESSION_LORAS=true`
- the default is `wan22-face-naturalizer.safetensors` from `wangkanai/wan22-fp16-i2v-loras`
- the same collection also includes `wan22-action-wink-i2v-v1-low.safetensors` for a more specific wink/action test
- to install both:

```bash
INSTALL_EXPRESSION_LORAS=true \
EXPRESSION_LORA_REPO="wangkanai/wan22-fp16-i2v-loras" \
EXPRESSION_LORA_FILES="loras/wan/wan22-face-naturalizer.safetensors,loras/wan/wan22-action-wink-i2v-v1-low.safetensors" \
./install_fresh_wan_comfyui.sh
```

IPAdapter FaceID still-image path:

- install with `INSTALL_IPADAPTER_FACEID=true`
- this adds the current `ComfyUI_IPAdapter_plus` extension
- it installs `insightface` and `onnxruntime`
- it downloads the exact SD1.5 and SDXL FaceID files the current unified loader expects
- it also downloads the `realisticVisionV51_v51VAE` SD1.5 checkpoint used by the built-in `ipadapter_faceid` template

Example:

```bash
INSTALL_IPADAPTER_FACEID=true ./install_fresh_wan_comfyui.sh
```

## Sources

- ComfyUI Wan 2.2 native workflows:
  [docs.comfy.org/tutorials/video/wan/wan2_2](https://docs.comfy.org/tutorials/video/wan/wan2_2)
- ComfyUI-Manager installation:
  [github.com/Comfy-Org/ComfyUI-Manager](https://github.com/Comfy-Org/ComfyUI-Manager)
- Wan 2.2 I2V model page:
  [huggingface.co/Wan-AI/Wan2.2-I2V-A14B](https://huggingface.co/Wan-AI/Wan2.2-I2V-A14B)
- WanVideoWrapper:
  [github.com/kijai/ComfyUI-WanVideoWrapper](https://github.com/kijai/ComfyUI-WanVideoWrapper)
- Stand-In:
  [github.com/WeChatCV/Stand-In](https://github.com/WeChatCV/Stand-In)
- Stand-In official preprocessor node:
  [github.com/WeChatCV/Stand-In_Preprocessor_ComfyUI](https://github.com/WeChatCV/Stand-In_Preprocessor_ComfyUI)
- Wan 2.2 FP16 I2V expression LoRA collection:
  [huggingface.co/wangkanai/wan22-fp16-i2v-loras](https://huggingface.co/wangkanai/wan22-fp16-i2v-loras)
