#!/usr/bin/env bash

set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$PIPELINE_DIR/lib/common.sh"

DRY_RUN=false
ENV_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --env-file) ENV_FILE="${2:?--env-file requires a path}"; shift 2 ;;
    *) fail "Unknown option: $1" ;;
  esac
done
load_env_file "$ENV_FILE"

[[ "$PWD" == "$PROJECT_ROOT" ]] || fail "Run from project root: $PROJECT_ROOT"
require_cmd bash
require_cmd python3
require_cmd git

IMAGE="$PROJECT_ROOT/02-character/shot-images/shot-15-keyframe.png"
AUDIO="$PROJECT_ROOT/04-audio/dialogue/beat-05-untunglah-hanya-mimpi.wav"
PROMPT="$PROJECT_ROOT/03-shots/prompts/shot-15-wan-prompt.txt"
OUTPUT_DIR="$PROJECT_ROOT/05-generated-video/shot-15"
WAN_REPO_DIR="${WAN_REPO_DIR:-$PROJECT_ROOT/external/Wan2.2}"
WAN_S2V_CKPT_DIR="${WAN_S2V_CKPT_DIR:-$PROJECT_ROOT/models/Wan2.2-S2V-14B}"

if [[ "$DRY_RUN" == true ]]; then
  [[ -d "$WAN_REPO_DIR" ]] || log "Dry-run warning: Wan2.2 repository not present: $WAN_REPO_DIR"
  [[ -f "$WAN_REPO_DIR/generate.py" ]] || log "Dry-run warning: official generate.py not present"
  [[ -d "$WAN_S2V_CKPT_DIR" ]] || log "Dry-run warning: S2V checkpoint not present: $WAN_S2V_CKPT_DIR"
else
  [[ -d "$WAN_REPO_DIR" ]] || fail "Wan2.2 repository not found: $WAN_REPO_DIR"
  [[ -f "$WAN_REPO_DIR/generate.py" ]] || fail "Official Wan2.2 generate.py not found"
  [[ -d "$WAN_S2V_CKPT_DIR" ]] || fail "S2V checkpoint directory not found: $WAN_S2V_CKPT_DIR"
fi
[[ -f "$IMAGE" ]] || fail "POC image not found: $IMAGE"
[[ -f "$AUDIO" ]] || fail "POC dialogue WAV not found: $AUDIO"
[[ -s "$PROMPT" ]] || fail "POC prompt file is missing or empty: $PROMPT"
prompt_char_count="$(validate_prompt_file "$PROMPT")" || fail "POC prompt validation failed: $PROMPT"
log "POC prompt validated: ${prompt_char_count} characters"
mkdir -p "$OUTPUT_DIR"
[[ -w "$OUTPUT_DIR" ]] || fail "Output directory is not writable: $OUTPUT_DIR"

if [[ "$DRY_RUN" == true ]]; then
  log "Dry-run preflight passed for project paths and POC inputs."
  for command_name in ffmpeg ffprobe nvidia-smi; do
    command -v "$command_name" >/dev/null 2>&1 || log "Dry-run warning: runtime command unavailable locally: $command_name"
  done
  log "Dry-run intentionally skipped GPU, CUDA, torch, RAM, disk, and media probing."
  exit 0
fi

require_cmd ffmpeg
require_cmd ffprobe
require_cmd nvidia-smi

torch_info="$(python3 - <<'PY'
import sys
try:
    import torch
except Exception as exc:
    print(f"IMPORT_ERROR:{exc}")
    raise SystemExit(1)
print(torch.__version__)
print(torch.cuda.is_available())
if torch.cuda.is_available():
    print(torch.cuda.get_device_name(0))
    print(torch.cuda.get_device_properties(0).total_memory)
PY
)" || fail "PyTorch import/CUDA check failed"
torch_version="$(printf '%s\n' "$torch_info" | sed -n '1p')"
cuda_available="$(printf '%s\n' "$torch_info" | sed -n '2p')"
[[ "$cuda_available" == true ]] || fail "CUDA is not visible to PyTorch"
python3 - "$torch_version" <<'PY' || exit 1
import sys
parts = tuple(int(part) for part in sys.argv[1].split('+')[0].split('.')[:2])
if parts < (2, 4):
    raise SystemExit('PyTorch must be >= 2.4.0')
PY

vram_bytes="$(printf '%s\n' "$torch_info" | sed -n '4p')"
python3 - "$vram_bytes" <<'PY' || exit 1
import sys
if int(sys.argv[1]) < 80 * 1024**3:
    raise SystemExit('S2V requires at least 80 GiB GPU VRAM')
PY

ram_kb="$(awk '/MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || true)"
[[ -n "$ram_kb" ]] || fail "Unable to determine system RAM on this platform"
(( ram_kb >= 64 * 1024 * 1024 )) || fail "System RAM is below practical 64 GiB preflight threshold"
free_kb="$(df -Pk "$PROJECT_ROOT" | awk 'NR==2 {print $4}')"
(( free_kb >= 50 * 1024 * 1024 )) || fail "Free disk is below 50 GiB preflight threshold"

audio_duration="$(duration_seconds "$AUDIO")"
[[ -n "$audio_duration" ]] || fail "Audio duration could not be read"
sample_rate="$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$AUDIO")"
[[ -n "$sample_rate" ]] || fail "Audio sample rate could not be read"
log "Preflight passed: torch=$torch_version, GPU=$(printf '%s\n' "$torch_info" | sed -n '3p'), VRAM=${vram_bytes} bytes, RAM=${ram_kb} KiB, audio=${audio_duration}s, sample_rate=${sample_rate}Hz"
