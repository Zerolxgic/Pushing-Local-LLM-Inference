#!/usr/bin/env bash
# Phase 0 machine-baseline capture for Pushing-Local-LLM-Inference
# Read-only with respect to system configuration. It only creates the output directory/file.

set -uo pipefail
export LC_ALL=C

SCRIPT_VERSION="0.1.0"
PROJECT_ROOT="${PROJECT_ROOT:-$HOME/AI-Training/Pushing-Local-LLM-Inference}"
OUT_DIR="${OUT_DIR:-$PROJECT_ROOT/raw-results/phase-0}"
STAMP="$(date '+%Y%m%d-%H%M%S%z')"
OUT_FILE="$OUT_DIR/machine-baseline-$STAMP.txt"

mkdir -p "$OUT_DIR"

section() {
  printf '\n\n===== %s =====\n' "$1"
}

run() {
  printf '\n$'
  printf ' %q' "$@"
  printf '\n'
  "$@" 2>&1
  local rc=$?
  if (( rc != 0 )); then
    printf '[exit=%d]\n' "$rc"
  fi
  return 0
}

run_shell() {
  local cmd="$1"
  printf '\n$ %s\n' "$cmd"
  bash -o pipefail -c "$cmd" 2>&1
  local rc=$?
  if (( rc != 0 )); then
    printf '[exit=%d]\n' "$rc"
  fi
  return 0
}

show_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '%-18s %s\n' "$cmd" "$(command -v "$cmd")"
  else
    printf '%-18s %s\n' "$cmd" 'NOT FOUND'
  fi
}

bytes_line() {
  local label="$1"
  local path="$2"
  if [[ -r "$path" ]]; then
    local b
    b="$(<"$path")"
    awk -v label="$label" -v b="$b" 'BEGIN { printf "%-24s %s bytes (%.3f GiB)\n", label, b, b/1073741824 }'
  fi
}

capture_gpu_sysfs() {
  local card devpath
  for card in /sys/class/drm/card[0-9]*; do
    [[ -e "$card/device" ]] || continue
    devpath="$(readlink -f "$card/device" 2>/dev/null || true)"
    printf '\n-- %s --\n' "$(basename "$card")"
    printf 'device_path              %s\n' "$devpath"
    [[ -r "$card/device/vendor" ]] && printf 'vendor_id                %s\n' "$(<"$card/device/vendor")"
    [[ -r "$card/device/device" ]] && printf 'device_id                %s\n' "$(<"$card/device/device")"
    [[ -L "$card/device/driver" ]] && printf 'driver                   %s\n' "$(basename "$(readlink -f "$card/device/driver")")"
    bytes_line 'VRAM total' "$card/device/mem_info_vram_total"
    bytes_line 'VRAM used'  "$card/device/mem_info_vram_used"
    bytes_line 'GTT total'  "$card/device/mem_info_gtt_total"
    bytes_line 'GTT used'   "$card/device/mem_info_gtt_used"
  done
}

{
  printf 'Pushing Local LLM Inference - Phase 0 Machine Baseline\n'
  printf 'capture_script_version: %s\n' "$SCRIPT_VERSION"
  printf 'captured_local: %s\n' "$(date --iso-8601=seconds)"
  printf 'captured_utc:   %s\n' "$(date -u --iso-8601=seconds)"
  printf 'project_root:   %s\n' "$PROJECT_ROOT"
  printf 'output_file:    %s\n' "$OUT_FILE"
  if command -v sha256sum >/dev/null 2>&1; then
    printf 'script_sha256:  %s\n' "$(sha256sum "$0" | awk '{print $1}')"
  fi

  section 'Operating system and kernel'
  run uname -r
  run uname -m
  if [[ -r /etc/os-release ]]; then
    run_shell "grep -E '^(NAME|PRETTY_NAME|ID|BUILD_ID|VERSION|VERSION_ID)=' /etc/os-release"
  fi
  printf '\nsession_type: %s\n' "${XDG_SESSION_TYPE:-unknown}"
  printf 'desktop:      %s\n' "${XDG_CURRENT_DESKTOP:-unknown}"

  section 'CPU and topology'
  if command -v lscpu >/dev/null 2>&1; then
    run lscpu
  else
    printf 'lscpu: NOT FOUND\n'
  fi
  if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
    printf '\ncpu0_scaling_governor: %s\n' "$(</sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
  fi
  if command -v powerprofilesctl >/dev/null 2>&1; then
    run powerprofilesctl get
  fi

  section 'System memory and swap - idle snapshot'
  if command -v free >/dev/null 2>&1; then
    run free -h
    run free -b
  fi
  run_shell "grep -E '^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapCached|SwapTotal|SwapFree|HugePages_Total|HugePages_Free|Hugepagesize):' /proc/meminfo"
  if command -v swapon >/dev/null 2>&1; then
    run swapon --show --bytes
  fi
  if [[ -r /proc/swaps ]]; then
    run cat /proc/swaps
  fi

  section 'Largest resident processes - idle snapshot'
  if command -v ps >/dev/null 2>&1; then
    run_shell "ps -eo comm,rss,%mem --sort=-rss | head -n 16"
  fi

  section 'GPU PCI identity and kernel driver'
  if command -v lspci >/dev/null 2>&1; then
    run_shell "lspci -nnk | grep -A4 -Ei 'VGA compatible controller|3D controller|Display controller'"
  else
    printf 'lspci: NOT FOUND\n'
  fi
  if command -v modinfo >/dev/null 2>&1; then
    run_shell "modinfo amdgpu 2>/dev/null | grep -E '^(filename|version|license|srcversion|vermagic):'"
  fi

  section 'GPU memory - kernel sysfs snapshot'
  capture_gpu_sysfs

  section 'AMD management tooling'
  show_cmd amd-smi
  show_cmd rocm-smi
  show_cmd rocminfo
  show_cmd hipconfig

  if command -v amd-smi >/dev/null 2>&1; then
    run amd-smi version
    run amd-smi metric --mem-usage --temperature --power
  fi
  if command -v rocm-smi >/dev/null 2>&1; then
    run rocm-smi --showmeminfo vram
  fi
  if command -v hipconfig >/dev/null 2>&1; then
    run hipconfig --version
  fi
  if command -v rocminfo >/dev/null 2>&1; then
    run_shell "rocminfo 2>/dev/null | grep -E '^[[:space:]]*(Name:|Marketing Name:|Vendor Name:|Feature:|Wavefront Size:)' | head -n 120"
  fi

  section 'Vulkan and Mesa'
  show_cmd vulkaninfo
  show_cmd glxinfo
  if command -v vulkaninfo >/dev/null 2>&1; then
    run vulkaninfo --summary
  fi
  if command -v glxinfo >/dev/null 2>&1; then
    run glxinfo -B
  fi

  section 'Relevant Arch packages'
  if command -v pacman >/dev/null 2>&1; then
    run_shell "pacman -Q | grep -Ei '^(linux|mesa|lib32-mesa|libdrm|vulkan-radeon|lib32-vulkan-radeon|vulkan-tools|mesa-utils|rocm|hip|hsa|rocminfo|amd-smi|rocm-smi|llama)' | sort"
  else
    printf 'pacman: NOT FOUND\n'
  fi

  section 'Local inference runtimes'
  # We deliberately do NOT invoke `lms` here. LM Studio documents that an lms
  # command may start LM Studio if it is not already running, which would alter
  # the idle-state measurement we just captured.
  show_cmd lms
  if [[ -x "$HOME/.lmstudio/bin/lms" ]]; then
    printf '%-18s %s\n' 'lms fallback' "$HOME/.lmstudio/bin/lms"
  fi
  show_cmd llama-cli
  show_cmd llama-server
  show_cmd llmster

  if command -v llama-cli >/dev/null 2>&1; then
    run llama-cli --version
  fi
  if command -v llama-server >/dev/null 2>&1; then
    run llama-server --version
  fi

  printf '\nLM Studio note: lms was not executed by this baseline script to avoid auto-start side effects.\n'

  section 'Currently running model/runtime processes'
  run_shell "ps -eo comm,pid,rss,%mem | grep -Ei 'lm.?studio|llmster|llama|ollama|kobold|text-generation' | grep -v grep || true"

  section 'Storage'
  if command -v df >/dev/null 2>&1; then
    run df -hT /
    if [[ -e "$PROJECT_ROOT" ]]; then
      run df -hT "$PROJECT_ROOT"
    fi
  fi
  if command -v lsblk >/dev/null 2>&1; then
    run lsblk -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINTS,MODEL
  fi

  section 'Relevant inference environment variables'
  run_shell "env | grep -E '^(HIP|HSA|ROCR|ROCM|GGML|LLAMA|VULKAN)_' | sort || true"

  section 'Capture completeness hints'
  printf 'Missing utilities are recorded as NOT FOUND rather than treated as fatal.\n'
  printf 'Do not install anything just to satisfy Phase 0 until this artifact is reviewed.\n'
  printf 'This file records machine state; it is not a model-performance benchmark.\n'

} >"$OUT_FILE"

printf 'Phase 0 baseline captured.\n'
printf 'Output: %s\n' "$OUT_FILE"
printf '\nReview with:\n  less %q\n' "$OUT_FILE"
