# Wan2.2 POC Execution Guide

This guide runs the approved shot-15 POC first. The scripts do not install
dependencies, download models, retry failed inference, or assemble the film.

## Vast.ai setup

1. Rent an instance with at least 80 GiB NVIDIA VRAM for Wan2.2-S2V-14B.
   Use an image with Python compatible with the official dependency files,
   PyTorch >= 2.4.0, visible CUDA, installable `flash_attn`, `ffmpeg`, and
   `git`. The official Wan2.2 documentation does not lock a specific Python,
   CUDA, or driver version, so do not treat one as guaranteed here.
2. Clone this project and enter its root:

   ```sh
   git clone <project-film-repository-url> project-film
   cd project-film
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

5. Copy the example environment file and edit paths for the instance:

   ```sh
   cp config/poc.env.example config/poc.env
   ${EDITOR:-vi} config/poc.env
   ```

6. Run preflight, then the POC:

   ```sh
   bash pipeline/preflight.sh --env-file config/poc.env
   bash pipeline/run-poc.sh --env-file config/poc.env
   ```

7. Review `05-generated-video/shot-15/shot-15-video-raw.mp4` and its metadata.
   Human approval is required before proceeding.

The POC sends only `03-shots/prompts/shot-15-wan-prompt.txt` to Wan2.2. The
longer `03-shots/prompts/shot-15-prompt.txt` remains creative documentation
and is not changed.

8. After approval, keep `shot-15` in the manifest as the first completed
   reference and add only validated, correctly assigned shots. Do not invent
   model or audio assignments.

9. Download the approved raw shot outputs and run production:

   ```sh
   bash pipeline/run-production.sh --env-file config/poc.env
   ```

10. Download all accepted outputs, then destroy the Vast.ai instance.

For local validation without a GPU, use `--dry-run`. It validates project
paths and prints the official `generate.py` command without installing,
downloading, probing media, or creating a video:

```sh
bash pipeline/run-poc.sh --env-file config/poc.env --dry-run
bash pipeline/run-production.sh --env-file config/poc.env --dry-run
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
