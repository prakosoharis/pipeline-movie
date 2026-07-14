# Wan2.2 POC Execution Guide

This guide runs the Shot 15 POC first and adds the production checkpoint only
after human approval. The setup scripts do not retry failed inference.
The deployment phases are recorded in `pipeline/manifest.json`; the 22-shot
generation assignments remain in `config/production-manifest.json`.

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

3. Copying an environment file is optional; use it only when paths differ:

   ```sh
   cp config/poc.env.example config/poc.env
   ${EDITOR:-vi} config/poc.env
   ```

4. Run the Phase 1 setup. It installs dependencies, validates CUDA and
   PyTorch, installs FlashAttention, clones Wan2.2 if needed, downloads only
   `Wan-AI/Wan2.2-S2V-14B`, and runs preflight:

   ```sh
   bash pipeline/setup-poc.sh
   ```

5. Render Shot 15:

   ```sh
   bash pipeline/run-poc.sh
   ```

6. Review `05-generated-video/shot-15/shot-15-video-raw.mp4` and its metadata.
   Record the human decision in `05-generated-video/shot-15/shot-15-validation.md`
   with an explicit line:

   ```text
   APPROVAL STATUS: APPROVED
   ```

   Do not run the production model setup unless this approval exists.

The POC sends only `03-shots/prompts/shot-15-wan-prompt.txt` to Wan2.2. The
longer `03-shots/prompts/shot-15-prompt.txt` remains creative documentation
and is not changed.

7. Add the production TI2V checkpoint. This validates the S2V checkpoint and
   Shot 15 approval, then downloads only `Wan-AI/Wan2.2-TI2V-5B`. It does not
   reinstall PyTorch, CUDA, FlashAttention, or run inference:

   ```sh
   bash pipeline/setup-production-models.sh
   ```

8. Run production. With the standard layout:

   ```sh
   bash pipeline/run-production.sh
   ```

9. Download all accepted outputs, then destroy the Vast.ai instance.

The deployment flow is:

```text
setup-poc.sh
        |
        v
run-poc.sh (Shot 15)
        |
        v
Human Review / Approval Shot 15
        |
        v
setup-production-models.sh (TI2V only)
        |
        v
run-production.sh (all approved READY shots)
```

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
