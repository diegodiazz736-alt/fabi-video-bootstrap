# Fabi Video Generation Bootstrap

Local-first bootstrap scripts and notes for running image-to-video workflows on cloud GPUs, with a current focus on strong facial identity consistency from multiple reference images.

## Included

- `bootstrap_skyreels_v3.sh`
  - Installs the official SkyReels V3 repo and local `SkyReels-V3-R2V-14B` model for multi-reference reference-to-video generation.
- `run_skyreels_r2v.sh`
  - Small helper wrapper for running local SkyReels reference-to-video jobs.
- `skyreels-r2v-notes.md`
  - Practical operating notes for identity-first SkyReels usage on an H100.
- `bootstrap_comfy_wan22.sh`
  - Earlier ComfyUI + Wan 2.2 bootstrap script kept as a fallback/general video workflow path.
- `wan22-comfyui-notes.md`
  - Notes for the Wan 2.2 setup.

## Recommended Path

For multi-image character consistency and strong subject identity retention, start with SkyReels:

```bash
./bootstrap_skyreels_v3.sh
```

Then run:

```bash
REF_IMGS="/abs/front.png,/abs/three_quarter.png,/abs/profile.png" \
PROMPT="A cinematic close portrait. The subject makes a slight head turn and breathes naturally. Slow dolly in. Stable facial identity, natural micro-expressions, soft ambient motion." \
$HOME/skyreels-local/run-skyreels-r2v.sh
```

## Notes

- Everything here is intended for local execution on your own machine or rented GPU instance.
- No external generation APIs are required.
- The SkyReels route is currently more natural via its own inference repo than via a polished stock ComfyUI workflow.
