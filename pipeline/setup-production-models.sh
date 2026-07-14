#!/usr/bin/env bash

set -euo pipefail

# Phase 2 setup: add only the production TI2V checkpoint after POC approval.
PROJECT_ROOT="${PROJECT_ROOT:-/workspace/project-film}"
WAN_REPO_DIR="${WAN_REPO_DIR:-$PROJECT_ROOT/external/Wan2.2}"
WAN_S2V_CKPT_DIR="${WAN_S2V_CKPT_DIR:-$PROJECT_ROOT/models/Wan2.2-S2V-14B}"
WAN_TI2V_CKPT_DIR="${WAN_TI2V_CKPT_DIR:-$PROJECT_ROOT/models/Wan2.2-TI2V-5B}"
SHOT15_OUTPUT="$PROJECT_ROOT/05-generated-video/shot-15/shot-15-video-raw.mp4"
SHOT15_APPROVAL_FILE="${SHOT15_APPROVAL_FILE:-$PROJECT_ROOT/05-generated-video/shot-15/shot-15-validation.md}"

log() { printf '[vastai-production-setup] %s\n' "$*"; }
fail() { log "ERROR: $*" >&2; exit 1; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

[[ -d "$PROJECT_ROOT" ]] || fail "Project root not found: $PROJECT_ROOT"
cd "$PROJECT_ROOT"
[[ -f pipeline/preflight.sh ]] || fail "Run this from the project repository: $PROJECT_ROOT"
[[ -d "$WAN_REPO_DIR" ]] || fail "Wan2.2 repository not found: $WAN_REPO_DIR"
[[ -f "$WAN_REPO_DIR/generate.py" ]] || fail "Wan2.2 generate.py not found: $WAN_REPO_DIR"
[[ -d "$WAN_S2V_CKPT_DIR" ]] || fail "S2V checkpoint directory not found: $WAN_S2V_CKPT_DIR"
[[ -f "$WAN_S2V_CKPT_DIR/.download-complete" ]] || fail \
  "S2V checkpoint marker not found: $WAN_S2V_CKPT_DIR/.download-complete"
[[ -s "$SHOT15_OUTPUT" ]] || fail "Shot 15 output not found or empty: $SHOT15_OUTPUT"
[[ -f "$SHOT15_APPROVAL_FILE" ]] || fail \
  "Shot 15 approval record not found: $SHOT15_APPROVAL_FILE"

python3 - "$SHOT15_APPROVAL_FILE" <<'PY'
import re
import sys
from pathlib import Path

approval_file = Path(sys.argv[1])
pattern = re.compile(
    r'^\s*(APPROVAL STATUS|approval_status)\s*[:=]\s*["\']?APPROVED["\']?\s*$',
    re.IGNORECASE,
)
if not any(pattern.match(line) for line in approval_file.read_text(encoding="utf-8").splitlines()):
    raise SystemExit(f"Shot 15 is not explicitly approved in: {approval_file}")
PY
log "Shot 15 approval confirmed: $SHOT15_APPROVAL_FILE"

has_cmd python3 || fail "python3 is required"

log "Validating Wan2.2 production runtime before model download."
python3 - "$WAN_REPO_DIR" <<'PY'
import sys
from pathlib import Path

from packaging.version import Version

wan_repo = Path(sys.argv[1])
sys.path.insert(0, str(wan_repo))

import diffusers
import flash_attn
import peft
import torch
import wan

if not torch.cuda.is_available():
    raise SystemExit("CUDA is not available to PyTorch")
if Version(peft.__version__) < Version("0.17.0"):
    raise SystemExit(f"peft>=0.17.0 is required; found {peft.__version__}")

print(f"torch: {torch.__version__}")
print(f"torch CUDA: {torch.version.cuda}")
print(f"GPU: {torch.cuda.get_device_name(0)}")
print(f"diffusers: {diffusers.__version__}")
print(f"peft: {peft.__version__}")
print(f"flash_attn: {getattr(flash_attn, '__version__', 'installed')}")
print("Wan2.2 import: PASS")
PY

if has_cmd huggingface-cli; then
  hf_command=huggingface-cli
elif has_cmd hf; then
  hf_command=hf
else
  log "Hugging Face CLI not found; installing only huggingface_hub CLI."
  python3 -m pip install "huggingface_hub[cli]"
  if has_cmd huggingface-cli; then hf_command=huggingface-cli
  elif has_cmd hf; then hf_command=hf
  else fail "Hugging Face CLI was not installed"; fi
fi

validate_checkpoint() {
  local checkpoint_dir="$1"
  local marker="$checkpoint_dir/.download-complete"
  [[ -d "$checkpoint_dir" ]] || fail "Checkpoint directory not found: $checkpoint_dir"
  [[ -f "$marker" ]] || fail "Checkpoint marker not found: $marker"
  find "$checkpoint_dir" -type f ! -name '.download-complete' -print -quit | grep -q . || \
    fail "Checkpoint directory contains no model files: $checkpoint_dir"
}

ensure_ti2v_checkpoint() {
  local model_repo="Wan-AI/Wan2.2-TI2V-5B"
  local checkpoint_marker="$WAN_TI2V_CKPT_DIR/.download-complete"
  if [[ -f "$checkpoint_marker" ]]; then
    log "TI2V checkpoint marker found; download skipped: $checkpoint_marker"
    return 0
  fi
  mkdir -p "$WAN_TI2V_CKPT_DIR"
  log "Downloading production checkpoint: $model_repo"
  "$hf_command" download "$model_repo" --local-dir "$WAN_TI2V_CKPT_DIR"
  touch "$checkpoint_marker"
  log "TI2V checkpoint download completed; marker created: $checkpoint_marker"
}

validate_checkpoint "$WAN_S2V_CKPT_DIR"
ensure_ti2v_checkpoint
validate_checkpoint "$WAN_TI2V_CKPT_DIR"

printf '\n'
log "Production checkpoint validation passed."
log "S2V checkpoint: $WAN_S2V_CKPT_DIR"
du -sh "$WAN_S2V_CKPT_DIR"
log "TI2V checkpoint: $WAN_TI2V_CKPT_DIR"
du -sh "$WAN_TI2V_CKPT_DIR"
log "No PyTorch, CUDA, flash-attn, or inference step was run by this script."
