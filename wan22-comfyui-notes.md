# Wan 2.2 on an H100: practical starting point

For what you described, the strongest current starting point is the official **ComfyUI native Wan 2.2 14B I2V** workflow, not a random community graph.

Why this is the right default:

- It is the official ComfyUI image-to-video path for Wan 2.2.
- Wan 2.2 A14B is explicitly positioned for image-to-video and supports **480p and 720p** generation.
- The upstream Wan 2.2 I2V model page shows **1280x720 single-GPU inference on at least 80 GB VRAM**, which lines up well with an H100.
- You keep closer to current ComfyUI core nodes, so fresh-machine rebuilds are less fragile than a deep stack of custom nodes.

## What to start with

Primary workflow:

- `wan22_14b_i2v_official.json`

Use this when:

- you have a strong reference image
- you want the model to preserve subject identity, framing, mood, and composition
- you care more about quality and cohesion than raw iteration speed

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

## What the bootstrap script does

`bootstrap_comfy_wan22.sh` will:

- create a Python venv
- install PyTorch with CUDA wheels
- clone and update ComfyUI
- install ComfyUI-Manager
- download the official Wan 2.2 workflow JSON files
- download the model files needed for either:
  - `MODEL_PRESET=a14b_i2v`
  - `MODEL_PRESET=ti2v_5b`
  - `MODEL_PRESET=full`
- write a `run-comfyui.sh` launcher

## Recommended first run

```bash
chmod +x /Users/duncangreen/Documents/Fabi/bootstrap_comfy_wan22.sh
MODEL_PRESET=a14b_i2v /Users/duncangreen/Documents/Fabi/bootstrap_comfy_wan22.sh
```

Then on the server:

```bash
$HOME/ai-video/run-comfyui.sh
```

Then in ComfyUI:

- load `$HOME/ai-video/workflows/wan22/wan22_14b_i2v_official.json`
- upload your reference image
- start around `1280x720`
- keep the first motion prompt simple

## Sources

- ComfyUI Wan 2.2 native workflows:
  [docs.comfy.org/tutorials/video/wan/wan2_2](https://docs.comfy.org/tutorials/video/wan/wan2_2)
- ComfyUI-Manager installation:
  [github.com/Comfy-Org/ComfyUI-Manager](https://github.com/Comfy-Org/ComfyUI-Manager)
- Wan 2.2 I2V model page:
  [huggingface.co/Wan-AI/Wan2.2-I2V-A14B](https://huggingface.co/Wan-AI/Wan2.2-I2V-A14B)
