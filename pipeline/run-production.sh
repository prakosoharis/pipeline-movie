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

PREFLIGHT_ARGS=()
[[ "$DRY_RUN" == true ]] && PREFLIGHT_ARGS+=(--dry-run)
[[ -n "$ENV_FILE" ]] && PREFLIGHT_ARGS+=(--env-file "$ENV_FILE")
"$PIPELINE_DIR/preflight.sh" "${PREFLIGHT_ARGS[@]}"

MANIFEST="$PROJECT_ROOT/config/production-manifest.json"
WAN_REPO_DIR="${WAN_REPO_DIR:?Set WAN_REPO_DIR in environment or env file}"
[[ -f "$MANIFEST" ]] || fail "Manifest not found: $MANIFEST"
require_cmd python3

while IFS=$'\t' read -r shot_id enabled status model_type task model_env image audio prompt_file size output; do
  [[ "$enabled" == true ]] || { log "$shot_id: skip, disabled"; continue; }
  [[ "$status" == READY ]] || { log "$shot_id: skip, status=$status"; continue; }
  case "$model_type" in
    S2V|TI2V|I2V) ;;
    *) fail "$shot_id: unsupported model_type: $model_type" ;;
  esac
  [[ -e "$output" ]] && { log "$shot_id: skip, output already exists: $output"; continue; }
  [[ -f "$image" ]] || fail "$shot_id: image not found: $image"
  [[ -s "$prompt_file" ]] || fail "$shot_id: prompt file missing or empty: $prompt_file"
  prompt_char_count="$(validate_prompt_file "$prompt_file")" || fail "$shot_id: prompt validation failed: $prompt_file"
  if [[ "$audio" != null && ! -f "$audio" ]]; then fail "$shot_id: audio not found: $audio"; fi
  checkpoint="${!model_env-}"
  [[ -n "$checkpoint" ]] || fail "$shot_id: environment variable is empty: $model_env"
  if [[ "$DRY_RUN" == true ]]; then
    [[ -d "$checkpoint" ]] || log "$shot_id: dry-run warning, checkpoint not present: $checkpoint"
    [[ -f "$WAN_REPO_DIR/generate.py" ]] || log "$shot_id: dry-run warning, generate.py not present: $WAN_REPO_DIR"
  else
    [[ -d "$checkpoint" ]] || fail "$shot_id: checkpoint directory not found: $checkpoint"
    [[ -f "$WAN_REPO_DIR/generate.py" ]] || fail "Wan2.2 generate.py not found: $WAN_REPO_DIR"
  fi

  prompt="$(<"$prompt_file")"
  model="$task"
  command=(python3 "$WAN_REPO_DIR/generate.py" --task "$task" --size "$size" --ckpt_dir "$checkpoint" \
    --offload_model True --convert_model_dtype --prompt "$prompt" --image "$image" --save_file "$output")
  [[ "$audio" == null ]] || command+=(--audio "$audio")
  if [[ "$DRY_RUN" == true ]]; then
    log "$shot_id: dry-run official inference command:"
    printf '%q ' "${command[@]}"; printf '\n'
    continue
  fi

  log_file="$PROJECT_ROOT/logs/$shot_id-$(date -u '+%Y%m%dT%H%M%SZ').log"
  mkdir -p "$(dirname "$output")" logs
  (
    exec > >(tee -a "$log_file") 2>&1
    started_at="$(timestamp)"; start_epoch="$(date +%s)"
    log "Starting $shot_id ($model_type/$task)."
    "${command[@]}"
    [[ -s "$output" ]] || fail "$shot_id: output missing or empty"
    [[ "$(stream_count v:0 "$output")" -gt 0 ]] || fail "$shot_id: output has no video stream"
    muxed=false
    if [[ "$audio" != null && "$(stream_count a:0 "$output")" -eq 0 ]]; then
      temp_output="${output}.muxing.tmp.mp4"
      ffmpeg -y -i "$output" -i "$audio" -map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -shortest "$temp_output"
      mv "$temp_output" "$output"
      muxed=true
    fi
    finished_at="$(timestamp)"; elapsed_seconds="$(( $(date +%s) - start_epoch ))"
    json_metadata "$output" "$task" "$model" "$checkpoint" "$image" "$audio" "$prompt_file" \
      "$started_at" "$finished_at" "$elapsed_seconds" "GENERATED" "$muxed" \
      "$(dirname "$output")/${shot_id}-metadata.json"
    log "$shot_id: complete."
  ) || { log "$shot_id: failed; stopping production. Log: $log_file" >&2; exit 1; }
done < <(python3 - "$MANIFEST" "$PROJECT_ROOT" <<'PY'
import json, os, sys
manifest, root = sys.argv[1:]
with open(manifest, encoding='utf-8') as handle:
    data = json.load(handle)
if not isinstance(data, list):
    raise SystemExit('production manifest must be a JSON array')
for shot in data:
    def path_value(key):
        value = shot.get(key)
        return 'null' if value is None else os.path.join(root, value)
    values = [
        shot.get('shot_id', ''), str(shot.get('enabled', False)).lower(), shot.get('status', ''),
        shot.get('model_type', ''), shot.get('task', ''), shot.get('model_dir_env', ''),
        path_value('image'), path_value('audio'), path_value('prompt_file'), shot.get('size', ''),
        path_value('output'),
    ]
    print('\t'.join(values))
PY
)
