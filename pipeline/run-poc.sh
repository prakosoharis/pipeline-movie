#!/usr/bin/env bash

set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$PIPELINE_DIR/lib/common.sh"

DRY_RUN=false
FORCE=false
ENV_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --force) FORCE=true; shift ;;
    --env-file) ENV_FILE="${2:?--env-file requires a path}"; shift 2 ;;
    *) fail "Unknown option: $1" ;;
  esac
done
load_env_file "$ENV_FILE"
[[ "$PWD" == "$PROJECT_ROOT" ]] || fail "Run from project root: $PROJECT_ROOT"

PREFLIGHT_ARGS=()
[[ "$DRY_RUN" == true ]] && PREFLIGHT_ARGS+=(--dry-run)
[[ -n "$ENV_FILE" ]] && PREFLIGHT_ARGS+=(--env-file "$ENV_FILE")
"$PIPELINE_DIR/preflight.sh" "${PREFLIGHT_ARGS[@]}"

WAN_REPO_DIR="${WAN_REPO_DIR:?Set WAN_REPO_DIR in environment or env file}"
WAN_S2V_CKPT_DIR="${WAN_S2V_CKPT_DIR:?Set WAN_S2V_CKPT_DIR in environment or env file}"
IMAGE="$PROJECT_ROOT/02-character/shot-images/shot-15-keyframe.png"
AUDIO="$PROJECT_ROOT/04-audio/dialogue/beat-05-untunglah-hanya-mimpi.wav"
PROMPT_FILE="$PROJECT_ROOT/03-shots/prompts/shot-15-wan-prompt.txt"
OUTPUT="$PROJECT_ROOT/05-generated-video/shot-15/shot-15-video-raw.mp4"
METADATA="$PROJECT_ROOT/05-generated-video/shot-15/shot-15-metadata.json"
mkdir -p "$(dirname "$OUTPUT")" logs

if [[ -e "$OUTPUT" && "$FORCE" != true ]]; then
  fail "Output exists; refusing overwrite. Use --force only after explicit review: $OUTPUT"
fi

PROMPT_CHAR_COUNT="$(validate_prompt_file "$PROMPT_FILE")" || fail "Prompt validation failed: $PROMPT_FILE"
PROMPT="$(<"$PROMPT_FILE")"
COMMAND=(python3 "$WAN_REPO_DIR/generate.py" --task s2v-14B --size '1024*704' \
  --ckpt_dir "$WAN_S2V_CKPT_DIR" --offload_model True --convert_model_dtype \
  --prompt "$PROMPT" --image "$IMAGE" --audio "$AUDIO" --save_file "$OUTPUT")

if [[ "$DRY_RUN" == true ]]; then
  log "Dry-run: official Wan2.2 inference arguments (human-readable preview)"
  printf '  task: %s\n' 's2v-14B'
  printf '  size: %s\n' '1024*704'
  printf '  checkpoint: %s\n' "$WAN_S2V_CKPT_DIR"
  printf '  image: %s\n' "$IMAGE"
  printf '  audio: %s\n' "$AUDIO"
  printf '  prompt file: %s\n' "$PROMPT_FILE"
  printf '  output: %s\n' "$OUTPUT"
  printf '  prompt characters: %s\n' "$PROMPT_CHAR_COUNT"
  printf '%s\n' '  prompt preview begin'
  printf '%s\n' "$PROMPT"
  printf '%s\n' '  prompt preview end'
  log "Dry-run: actual execution keeps the complete prompt as one argv value; generate.py was not run."
  exit 0
fi

LOG_FILE="$PROJECT_ROOT/logs/shot-15-$(date -u '+%Y%m%dT%H%M%SZ').log"
exec > >(tee -a "$LOG_FILE") 2>&1
started_at="$(timestamp)"; start_epoch="$(date +%s)"
log "Starting shot-15 S2V inference."
set +e
"${COMMAND[@]}"
inference_status=$?
set -e
[[ "$inference_status" -eq 0 ]] || fail "Wan2.2 inference failed. Log: $LOG_FILE"
[[ -s "$OUTPUT" ]] || fail "Wan2.2 returned no usable MP4: $OUTPUT"

muxed=false
video_streams="$(stream_count v:0 "$OUTPUT")"
audio_streams="$(stream_count a:0 "$OUTPUT")"
[[ "$video_streams" -gt 0 ]] || fail "Output has no video stream"
if [[ "$audio_streams" -eq 0 ]]; then
  log "Output has no audio stream; muxing the original dialogue WAV with FFmpeg."
  temp_output="${OUTPUT}.muxing.tmp.mp4"
  ffmpeg -y -i "$OUTPUT" -i "$AUDIO" -map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -shortest "$temp_output"
  mv "$temp_output" "$OUTPUT"
  muxed=true
fi

video_duration="$(duration_seconds "$OUTPUT")"
audio_duration="$(duration_seconds "$AUDIO")"
python3 - "$video_duration" "$audio_duration" <<'PY'
import sys
video, audio = map(float, sys.argv[1:])
if abs(video - audio) > max(0.5, audio * 0.10):
    raise SystemExit(f'Video/audio duration mismatch: video={video}, audio={audio}')
PY
finished_at="$(timestamp)"; elapsed_seconds="$(( $(date +%s) - start_epoch ))"
gpu_name="$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)"
torch_version="$(python3 -c 'import torch; print(torch.__version__)')"
cuda_version="$(python3 -c 'import torch; print(torch.version.cuda or "unknown")')"
WAN_GPU_NAME="$gpu_name" WAN_TORCH_VERSION="$torch_version" WAN_CUDA_VERSION="$cuda_version" \
  json_metadata "$OUTPUT" "s2v-14B" "Wan2.2-S2V-14B" "$WAN_S2V_CKPT_DIR" "$IMAGE" "$AUDIO" \
  "$PROMPT_FILE" "$started_at" "$finished_at" "$elapsed_seconds" "GENERATED" "$muxed" "$METADATA"
log "POC complete: $OUTPUT"
log "Log: $LOG_FILE"
