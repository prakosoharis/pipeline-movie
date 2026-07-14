#!/usr/bin/env bash

set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$PIPELINE_DIR/.." && pwd)}"

timestamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s] %s\n' "$(timestamp)" "$*"; }
fail() { log "ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

duration_seconds() {
  ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1"
}

stream_count() {
  ffprobe -v error -select_streams "$1" -show_entries stream=index \
    -of csv=p=0 "$2" | awk 'NF { count++ } END { print count + 0 }'
}

validate_prompt_file() {
  local prompt_file="$1"
  [[ -r "$prompt_file" ]] || fail "Prompt file cannot be read: $prompt_file"
  python3 - "$prompt_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
raw = path.read_bytes()
if b"\x00" in raw:
    raise SystemExit("Prompt contains a null byte")
if b"\r\n" in raw:
    raise SystemExit("Prompt contains CRLF line endings; use LF line endings")
text = raw.decode("utf-8")
print(len(text))
if len(text) > 2000:
    print("WARNING: prompt is longer than 2000 characters", file=sys.stderr)
PY
}

prompt_for_inference() {
  local prompt_file="$1"
  python3 - "$prompt_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
marker = "PROMPT VIDEO UTAMA:"
if marker in text:
    text = text.split(marker, 1)[1]
    if "NEGATIVE PROMPT:" in text:
        text = text.split("NEGATIVE PROMPT:", 1)[0]
print(text.strip())
PY
}

load_env_file() {
  local env_file="${1:-}"
  if [[ -n "$env_file" ]]; then
    [[ -f "$env_file" ]] || fail "Environment file not found: $env_file"
    # The env file is a local operator-owned configuration file.
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
  PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$PIPELINE_DIR/.." && pwd)}"
}

json_metadata() {
  local output="$1" task="$2" model="$3" checkpoint="$4" image="$5" audio="$6"
  local prompt_file="$7" started="$8" finished="$9" elapsed="${10}" status="${11}" muxed="${12}"
  local metadata="${13}"
  python3 - "$output" "$task" "$model" "$checkpoint" "$image" "$audio" \
    "$prompt_file" "$started" "$finished" "$elapsed" "$status" "$muxed" "$metadata" <<'PY'
import json
import os
import subprocess
import sys

(output, task, model, checkpoint, image, audio, prompt_file, started,
 finished, elapsed, status, muxed, metadata) = sys.argv[1:]

def probe(args):
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-of", "json"] + args + [output],
        check=True, capture_output=True, text=True,
    )
    return json.loads(result.stdout or "{}")

fmt = probe(["-show_entries", "format=duration"])
streams = probe(["-show_streams"]).get("streams", [])
video = next((s for s in streams if s.get("codec_type") == "video"), {})
audio_stream = next((s for s in streams if s.get("codec_type") == "audio"), {})
audio_duration = 0.0
if audio and os.path.exists(audio):
    raw = subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1", audio,
    ], text=True).strip()
    audio_duration = float(raw)

data = {
    "shot_id": os.path.basename(os.path.dirname(output)),
    "task": task,
    "model": model,
    "checkpoint_dir": checkpoint,
    "image": image,
    "audio": audio,
    "prompt_file": prompt_file,
    "output": output,
    "resolution": (f"{video.get('width', '')}x{video.get('height', '')}"
                   if video else ""),
    "audio_duration_seconds": audio_duration,
    "video_duration_seconds": float(fmt.get("format", {}).get("duration", 0)),
    "gpu": os.environ.get("WAN_GPU_NAME", "unknown"),
    "torch_version": os.environ.get("WAN_TORCH_VERSION", "unknown"),
    "cuda_version": os.environ.get("WAN_CUDA_VERSION", "unknown"),
    "started_at": started,
    "finished_at": finished,
    "elapsed_seconds": float(elapsed),
    "status": status,
    "audio_muxed_by_ffmpeg": muxed == "true",
}
with open(metadata, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2, ensure_ascii=True)
    handle.write("\n")
PY
}
