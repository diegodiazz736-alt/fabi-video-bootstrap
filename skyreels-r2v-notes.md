# SkyReels V3 R2V on an H100: practical starting point

For your specific requirement, the right local-first foundation is **SkyReels-V3-R2V-14B**.

Why this fits better than a plain image-to-video model:

- The official SkyReels V3 reference-to-video model is designed for **1 to 4 reference images**.
- The upstream model explicitly says it is built to maintain **strong identity fidelity** and narrative consistency.
- The official recommendation for the model is **5 seconds at 720p and 24 fps**, which is a good quality-first operating point on a single H100.
- This is a true local model path: the code runs on your box and can use a local model directory through `--model_id`.

## What this changes compared with Wan

Wan 2.2 is still useful, but its official self-hosted path is mainly:

- single-image image-to-video
- first/last-frame control

That is not the same as a multi-reference identity-conditioning workflow. For your project, SkyReels is the better primary stack.

## The tradeoff

The main downside is tooling, not model fit:

- SkyReels V3 is currently more naturally used through its own Python inference repo than through a polished stock ComfyUI workflow.
- If you want the strongest local identity-first setup today, that is a worthwhile trade.

## How to use the references well

Use 2 to 4 images that complement each other:

- one clean front-facing portrait
- one three-quarter view
- one profile or near-profile view
- optionally one wider image that captures hair, clothing, and silhouette

What matters:

- same person, same styling, same age, same lighting family if possible
- sharp eyes and face detail
- avoid wildly different makeup, hairstyle, lens distortion, or expression unless that change is intentional

## Best first-shot recipe

For your first tests, keep the shot simple:

- duration: `5`
- resolution: `720P`
- camera: static or very slow push-in
- motion: subtle head turn, blink, breath, slight fabric or hair motion
- prompt density: moderate, not overloaded

That gives the model the best chance to stay locked to identity instead of improvising.

## Suggested prompt pattern

```text
[who the subject is in the reference images],
[framing],
the subject makes [small intentional motion],
facial behavior: [subtle expression and eye movement],
camera motion: [static / slow dolly in / gentle pan],
environmental motion: [soft wind / light rain / cloth movement / reflections],
lighting and mood: [cinematic tone],
stable facial identity, coherent anatomy, natural motion
```

Example:

```text
A cinematic close portrait of the same woman shown in the reference images,
head and shoulders framing,
she slowly turns a few degrees toward camera and blinks naturally,
facial behavior: calm, focused expression with subtle eye movement,
camera motion: slow dolly in,
environmental motion: gentle wind through loose hair and collar fabric,
lighting and mood: moody evening light with soft contrast,
stable facial identity, coherent anatomy, natural motion
```

## Bootstrap summary

`bootstrap_skyreels_v3.sh` will:

- create a Python venv
- install CUDA PyTorch and the SkyReels repo requirements
- clone and update the official SkyReels V3 repo
- default `TORCH_CUDA_ARCH_LIST` to `9.0` for H100-targeted `flash_attn` builds
- optionally preload the `Skywork/SkyReels-V3-R2V-14B` model locally
- write a `run-skyreels-r2v.sh` helper on the remote machine
- write a prompt template and quick-start note

## Recommended first run

Bootstrap:

```bash
chmod +x /Users/duncangreen/Documents/Fabi/bootstrap_skyreels_v3.sh
/Users/duncangreen/Documents/Fabi/bootstrap_skyreels_v3.sh
```

Generate:

```bash
REF_IMGS="/abs/front.png,/abs/three_quarter.png,/abs/profile.png" \
PROMPT="A cinematic close portrait. The subject makes a slight head turn and breathes naturally. Slow dolly in. Stable facial identity, natural micro-expressions, soft ambient motion." \
$HOME/skyreels-local/run-skyreels-r2v.sh
```

## Sources

- SkyReels V3 official repo:
  [github.com/SkyworkAI/SkyReels-V3](https://github.com/SkyworkAI/SkyReels-V3)
- SkyReels V3 R2V model card:
  [huggingface.co/Skywork/SkyReels-V3-R2V-14B](https://huggingface.co/Skywork/SkyReels-V3-R2V-14B)
