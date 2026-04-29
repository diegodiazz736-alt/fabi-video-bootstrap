Bundled community workflows for "preserve one face, change the setting" tests.

Included:

- `ip-adapter-faceid-sdxl.json`
  - Source: `aimpowerment/comfyui-workflows`
  - Good first try when one face needs to stay recognizable and the rest of the scene can change.
- `simple-instantid-workflow.json`
  - Source: `aimpowerment/comfyui-workflows`
  - Stronger face locking path built around InstantID.

These are staged into the cloud install at:

- `$HOME/comfy-wan-local/workflows/community/` on a normal install
- `/ephemeral/comfy-wan-local/workflows/community/` on providers where the installer uses `/ephemeral`

Notes:

- These are community SDXL identity workflows, not Wan 2.2 native video workflows.
- They are useful for still-image identity-preservation tests and scene-transfer experiments.
- They may still require additional ComfyUI custom nodes and model assets beyond the base Wan bootstrap.
