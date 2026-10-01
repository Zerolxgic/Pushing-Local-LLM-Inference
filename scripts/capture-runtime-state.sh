#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

PROJECT_ROOT="${PROJECT_ROOT:-$HOME/AI-Training/Pushing-Local-LLM-Inference}"
OUT_DIR="${OUT_DIR:-$PROJECT_ROOT/raw-results/phase-0}"
STAMP="$(date '+%Y%m%d-%H%M%S%z')"
OUT_FILE="$OUT_DIR/runtime-state-$STAMP.txt"
mkdir -p "$OUT_DIR"

show_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    printf '%-18s %s\n' "$1" "$(command -v "$1")"
  else
    printf '%-18s NOT FOUND\n' "$1"
  fi
}

{
  echo 'Pushing Local LLM Inference - Supplemental Runtime State'
  echo "captured_local: $(date --iso-8601=seconds)"
  echo "captured_utc:   $(date -u --iso-8601=seconds)"
  echo
  echo '===== LM Studio ====='
  show_cmd lms
  if command -v lms >/dev/null 2>&1; then
    lms runtime ls 2>&1 || true
    lms ps 2>&1 || true
  fi

  echo
  echo '===== Standalone llama.cpp tooling ====='
  show_cmd llama-cli
  show_cmd llama-server
  show_cmd llmster

  echo
  echo '===== Vulkan ====='
  show_cmd vulkaninfo
  if command -v vulkaninfo >/dev/null 2>&1; then
    vulkaninfo --summary 2>&1 || true
  fi

  echo
  echo '===== ROCm / HIP ====='
  show_cmd rocminfo
  show_cmd hipconfig
  if command -v hipconfig >/dev/null 2>&1; then
    hipconfig --version 2>&1 || true
  fi
  if command -v rocminfo >/dev/null 2>&1; then
    rocminfo 2>/dev/null | grep -E '^[[:space:]]*(Name:|Marketing Name:|Vendor Name:|Feature:|Wavefront Size:)' | head -n 120 || true
  fi

  echo
  echo '===== Runtime processes ====='
  ps -eo comm,pid,rss,%mem | grep -Ei 'lm.?studio|llmster|llama|ollama|kobold|text-generation' | grep -v grep || true

  echo
  echo 'NOTE: invoking lms may start LM Studio; do not use this artifact as an idle-memory baseline.'
} > "$OUT_FILE"

printf 'Supplemental runtime state captured: %s\n' "$OUT_FILE"
