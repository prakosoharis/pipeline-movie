#!/usr/bin/env bash

set -euo pipefail

# Phase 1 setup for the standard Vast.ai POC layout.
PROJECT_ROOT="${PROJECT_ROOT:-/workspace/project-film}"
WAN_REPO_DIR="${WAN_REPO_DIR:-$PROJECT_ROOT/external/Wan2.2}"
WAN_S2V_CKPT_DIR="${WAN_S2V_CKPT_DIR:-$PROJECT_ROOT/models/Wan2.2-S2V-14B}"
MIN_VRAM_GIB="${MIN_VRAM_GIB:-86}"
MAX_JOBS="${MAX_JOBS:-8}"
LOG_DIR="$PROJECT_ROOT/logs"

log() { printf '[setup-poc] %s\n' "$*"; }
fail() { log "ERROR: $*" >&2; exit 1; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif has_cmd sudo; then
    sudo "$@"
  else
    fail "Root privileges are required to install OS packages."
  fi
}

[[ -d "$PROJECT_ROOT" ]] || fail "Project root not found: $PROJECT_ROOT"
cd "$PROJECT_ROOT"
[[ -f pipeline/preflight.sh ]] || fail "Run this from the project repository: $PROJECT_ROOT"

has_cmd bash || fail "bash is required"
has_cmd python3 || fail "python3 is required"

if ! has_cmd apt-get; then
  fail "This setup script expects an Ubuntu/Debian Vast.ai image with apt-get."
fi

missing_packages=()
has_cmd git || missing_packages+=(git)
has_cmd ffmpeg || missing_packages+=(ffmpeg)
has_cmd ffprobe || missing_packages+=(ffmpeg)
has_cmd g++ || missing_packages+=(build-essential)
has_cmd ninja || missing_packages+=(ninja-build)
python3 -m pip --version >/dev/null 2>&1 || missing_packages+=(python3-pip)

if [[ "${#missing_packages[@]}" -gt 0 ]]; then
  log "Installing missing OS packages: ${missing_packages[*]}"
  mapfile -t missing_packages < <(printf '%s\n' "${missing_packages[@]}" | awk '!seen[$0]++')
  as_root apt-get update
  as_root apt-get install -y "${missing_packages[@]}"
else
  log "Required OS commands are already installed."
fi

has_cmd nvidia-smi || fail "nvidia-smi is unavailable; choose a CUDA-enabled GPU instance."
has_cmd nvcc || fail "nvcc is unavailable. Select a CUDA devel image, not a runtime-only image."

nvcc_output="$(nvcc --version)"
cuda_toolkit_version="$(python3 - "$nvcc_output" <<'PY'
import re
import sys

match = re.search(r"release\s+(\d+)\.(\d+)", sys.argv[1])
if not match:
    raise SystemExit("Could not parse CUDA toolkit version from nvcc")
major, minor = map(int, match.groups())
if (major, minor) < (12, 0):
    raise SystemExit(f"CUDA toolkit must be >= 12.0; detected {major}.{minor}")
print(f"{major}.{minor}")
PY
)" || fail "CUDA toolkit validation failed; use a CUDA devel image."
log "CUDA devel toolkit detected: $cuda_toolkit_version"

gpu_name="$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)"
vram_mib="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1 | awk '{print $1}')"
[[ "$vram_mib" =~ ^[0-9]+$ ]] || fail "Could not parse GPU VRAM: $vram_mib"
vram_bytes=$((vram_mib * 1024 * 1024))
python3 - "$gpu_name" "$vram_bytes" "$MIN_VRAM_GIB" <<'PY'
import sys
name, vram_bytes, minimum_gib = sys.argv[1:]
vram_gib = int(vram_bytes) / 1024**3
print(f"GPU: {name}")
print(f"VRAM: {vram_gib:.2f} GiB")
if vram_gib < float(minimum_gib):
    raise SystemExit(
        f"GPU VRAM is below {minimum_gib} GiB; detected {vram_gib:.2f} GiB"
    )
PY

python3 - <<'PY'
try:
    import torch
except Exception:
    raise SystemExit("PyTorch is not importable")
print("torch:", torch.__version__)
print("cuda runtime:", torch.version.cuda)
print("cuda available:", torch.cuda.is_available())
version_parts = tuple(int(part) for part in torch.__version__.split('+')[0].split('.')[:2])
if version_parts < (2, 4):
    raise SystemExit("PyTorch must be >= 2.4.0")
if not torch.cuda.is_available():
    raise SystemExit("CUDA is not available to PyTorch")
print("torch GPU:", torch.cuda.get_device_name(0))
PY

free_kb="$(df -Pk "$PROJECT_ROOT" | awk 'NR==2 {print $4}')"
(( free_kb >= 150 * 1024 * 1024 )) || fail "At least 150 GiB free disk is required before model download."
log "Free disk check passed."

mkdir -p "$PROJECT_ROOT/external" "$PROJECT_ROOT/models" "$LOG_DIR"
if [[ ! -f "$WAN_REPO_DIR/generate.py" ]]; then
  [[ ! -e "$WAN_REPO_DIR" ]] || fail "Wan2.2 path exists but is not a valid checkout: $WAN_REPO_DIR"
  log "Cloning official Wan2.2 repository."
  git clone https://github.com/Wan-Video/Wan2.2.git "$WAN_REPO_DIR"
else
  log "Official Wan2.2 repository already exists."
fi

git -C "$WAN_REPO_DIR" rev-parse HEAD > "$LOG_DIR/wan2.2-commit.txt"
log "Wan2.2 commit: $(<"$LOG_DIR/wan2.2-commit.txt")"

cd "$WAN_REPO_DIR"
log "Installing deterministic build prerequisites."
python3 -m pip install packaging psutil ninja setuptools wheel
log "Installing Wan2.2 runtime dependency: peft."
python3 -m pip install peft==0.15.2 --no-deps

filtered_requirements="$(mktemp)"
trap 'rm -f "$filtered_requirements"' EXIT
awk '
  tolower($0) !~ /^[[:space:]]*flash[-_]attn([[:space:]<>=!~].*)?$/
  { print }
' requirements.txt > "$filtered_requirements"

log "Installing Wan2.2 requirements without flash-attn."
python3 -m pip install -r "$filtered_requirements"
log "Installing Wan2.2 S2V requirements."
python3 -m pip install -r requirements_s2v.txt

log "Validating PyTorch and CUDA toolkit compatibility before flash-attn."
python3 - "$cuda_toolkit_version" <<'PY'
import sys

import torch
from packaging.version import Version


def cuda_tuple(value):
    try:
        major, minor = value.split(".", 1)
        return int(major), int(minor)
    except (AttributeError, ValueError) as exc:
        raise SystemExit(f"Could not parse CUDA version: {value!r}") from exc


nvcc_cuda = sys.argv[1]
torch_cuda = torch.version.cuda
if torch_cuda is None:
    raise SystemExit("PyTorch does not expose a CUDA runtime version")

torch_cuda_parts = cuda_tuple(torch_cuda)
nvcc_cuda_parts = cuda_tuple(nvcc_cuda)
print(f"torch CUDA runtime: {torch_cuda}")
print(f"nvcc CUDA toolkit: {nvcc_cuda}")

if torch_cuda_parts != nvcc_cuda_parts:
    raise SystemExit(
        "CUDA version mismatch: PyTorch uses "
        f"{torch_cuda}, but nvcc reports {nvcc_cuda}. "
        "Install a matching CUDA devel toolkit before building flash-attn."
    )

if not torch.cuda.is_available():
    raise SystemExit("CUDA is not available to PyTorch")

torch_version = Version(torch.__version__.split("+", 1)[0])
capability = torch.cuda.get_device_capability(0)
arch_list = torch.cuda.get_arch_list()
print(f"PyTorch: {torch.__version__}")
print(f"GPU: {torch.cuda.get_device_name(0)}")
print(f"compute capability: {capability[0]}.{capability[1]}")
print(f"PyTorch architectures: {', '.join(arch_list)}")

if capability == (12, 0):
    if torch_version < Version("2.7.0"):
        raise SystemExit("Compute capability 12.0 requires PyTorch >= 2.7")
    if torch_cuda_parts < (12, 8):
        raise SystemExit("Compute capability 12.0 requires PyTorch CUDA >= 12.8")
    if nvcc_cuda_parts < (12, 8):
        raise SystemExit("Compute capability 12.0 requires nvcc CUDA >= 12.8")
    if "sm_120" not in arch_list:
        raise SystemExit(
            "Compute capability 12.0 requires sm_120 in "
            "torch.cuda.get_arch_list()"
        )
    print("Blackwell sm_120 compatibility checks: PASS")
PY

log "Installing flash-attn last with MAX_JOBS=$MAX_JOBS without changing PyTorch."
MAX_JOBS="$MAX_JOBS" python3 -m pip install flash-attn --no-build-isolation --no-deps
rm -f "$filtered_requirements"
trap - EXIT

cd "$PROJECT_ROOT"
if has_cmd huggingface-cli; then
  hf_command=huggingface-cli
elif has_cmd hf; then
  hf_command=hf
else
  python3 -m pip install "huggingface_hub[cli]"
  has_cmd huggingface-cli || has_cmd hf || fail "Hugging Face CLI was not installed"
  if has_cmd huggingface-cli; then hf_command=huggingface-cli; else hf_command=hf; fi
fi

ensure_checkpoint() {
  local model_repo="$1"
  local checkpoint_dir="$2"
  local checkpoint_marker="$checkpoint_dir/.download-complete"
  if [[ -f "$checkpoint_marker" ]]; then
    log "Checkpoint marker found; download skipped: $checkpoint_marker"
    return 0
  fi
  mkdir -p "$checkpoint_dir"
  log "Downloading official checkpoint: $model_repo"
  "$hf_command" download "$model_repo" --local-dir "$checkpoint_dir"
  touch "$checkpoint_marker"
  log "Checkpoint download completed; marker created: $checkpoint_marker"
}

ensure_checkpoint "Wan-AI/Wan2.2-S2V-14B" "$WAN_S2V_CKPT_DIR"

environment_log="$LOG_DIR/wan2.2-environment.txt"
{
  printf 'timestamp: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'python: '; python3 --version
  python3 - <<'PY'
import torch
print(f"torch: {torch.__version__}")
print(f"torch_cuda_runtime: {torch.version.cuda}")
PY
  printf 'nvcc: %s\n' "$cuda_toolkit_version"
  printf 'gpu: %s\n' "$gpu_name"
  python3 - <<'PY'
import importlib.metadata
import flash_attn
try:
    version = importlib.metadata.version("flash-attn")
except importlib.metadata.PackageNotFoundError:
    version = getattr(flash_attn, "__version__", "unknown")
print(f"flash_attn: {version}")
PY
} | tee "$environment_log"
log "Environment versions saved to: $environment_log"

log "Running project preflight."
PROJECT_ROOT="$PROJECT_ROOT" \
WAN_REPO_DIR="$WAN_REPO_DIR" \
WAN_S2V_CKPT_DIR="$WAN_S2V_CKPT_DIR" \
  bash pipeline/preflight.sh

log "POC setup complete. Run:"
log "  bash pipeline/run-poc.sh"
log "After human approval of shot-15:"
log "  bash pipeline/setup-production-models.sh"
log "  bash pipeline/run-production.sh"
