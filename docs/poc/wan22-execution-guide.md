# Wan2.2 POC Execution Guide

This guide runs the approved shot-15 POC first. The setup script performs
one-time dependency and checkpoint preparation. The runner scripts do not
retry failed inference.

## Vast.ai setup

1. Rent an instance with at least 80 GiB NVIDIA VRAM for Wan2.2-S2V-14B.
   Use an image with Python compatible with the official dependency files,
   PyTorch >= 2.4.0, visible CUDA, installable `flash_attn`, `ffmpeg`, and
   `git`. The official Wan2.2 documentation does not lock a specific Python,
   CUDA, or driver version, so do not treat one as guaranteed here.
2. Clone this project into the standard path and enter its root:

   ```sh
   mkdir -p /workspace
   git clone <project-film-repository-url> /workspace/project-film
   cd /workspace/project-film
   ```

   The scripts use these default paths, so `config/poc.env` is optional when
   this layout is used:

   ```text
   /workspace/project-film/
   ├── external/Wan2.2/
   └── models/Wan2.2-S2V-14B/
   ```

3. Clone the official Wan2.2 repository:

   ```sh
   mkdir -p external
   git clone https://github.com/Wan-Video/Wan2.2.git external/Wan2.2
   cd external/Wan2.2
   pip install -r requirements.txt
   pip install -r requirements_s2v.txt
   cd ../..
   ```

4. Download only the POC checkpoint first:

   ```sh
   mkdir -p models
   huggingface-cli download Wan-AI/Wan2.2-S2V-14B \
     --local-dir ./models/Wan2.2-S2V-14B
   ```

5. The checkpoint must be at `models/Wan2.2-S2V-14B/` for the default
   layout. Copying an environment file is optional; use it only when paths
   differ:

   ```sh
   cp config/poc.env.example config/poc.env
   ${EDITOR:-vi} config/poc.env
   ```

6. Run preflight, then the POC. With the standard layout, the shortest form
   is:

   ```sh
   bash pipeline/run-poc.sh
   ```

   When using non-default paths, pass `--env-file config/poc.env`.

   To perform the one-time setup automatically after SSH, use the repository
   setup script. It installs only missing OS packages, verifies the GPU and
   PyTorch, clones the official Wan2.2 repository, installs its requirements,
   downloads the S2V checkpoint if absent, and runs preflight:

   ```sh
   bash pipeline/vastai-setup.sh
   ```

   The setup downloads the S2V-14B and TI2V-5B checkpoints. This is required
   for the full production manifest.

7. Review `05-generated-video/shot-15/shot-15-video-raw.mp4` and its metadata.
   Human approval is required before proceeding.

The POC sends only `03-shots/prompts/shot-15-wan-prompt.txt` to Wan2.2. The
longer `03-shots/prompts/shot-15-prompt.txt` remains creative documentation
and is not changed.

8. After approval, keep `shot-15` in the manifest as the first completed
   reference and add only validated, correctly assigned shots. Do not invent
   model or audio assignments.

9. Download the approved raw shot outputs and run production. With the
   standard layout:

   ```sh
   bash pipeline/run-production.sh
   ```

10. Download all accepted outputs, then destroy the Vast.ai instance.

The production manifest contains all 22 shots in shot order. Dialogue shots
use S2V-14B with their dialogue WAV; non-dialogue shots use TI2V-5B. After all
raw shot MP4 files are available, `run-production.sh` normalizes them with
FFmpeg and writes the assembled film to `07-final/film-final.mp4`. Shots with
no generation audio receive a silent audio track during normalization so the
concat input has consistent streams.

For local validation without a GPU, use `--dry-run`. It validates project
paths and prints the official `generate.py` command without installing,
downloading, probing media, or creating a video:

```sh
bash pipeline/run-poc.sh --dry-run
bash pipeline/run-production.sh --dry-run
```

Optional local macOS audio validation:

```sh
brew install ffmpeg
ffprobe -v error \
  -show_entries format=duration \
  -show_entries stream=codec_name,sample_rate,channels \
  -of default=noprint_wrappers=1 \
  "04-audio/dialogue/beat-05-untunglah-hanya-mimpi.wav"
```

Expected audio properties are `codec_name=pcm_s16le`, `sample_rate=48000`,
and `channels=1`. FFmpeg is optional for local dry-run, but `ffmpeg` and
`ffprobe` are required on the Vast.ai runtime. `ffprobe` is normally included
with the FFmpeg installation.
