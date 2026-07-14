#!/usr/bin/env bash

set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$PIPELINE_DIR/.." && pwd)"

cd "$PROJECT_ROOT"
exec python3 "$PIPELINE_DIR/mix-audio.py" "$@"
