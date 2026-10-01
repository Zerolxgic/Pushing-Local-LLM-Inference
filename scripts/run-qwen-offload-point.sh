#!/usr/bin/env bash
set -euo pipefail

GPU="${1:?usage: $0 <gpu-offload-ratio>}"
MODEL="qwen/qwen3.6-35b-a3b"
CTX=4096
OUTROOT="raw-results/qwen-phase-1"
PROMPT='Explain in clear technical terms why memory bandwidth matters for local LLM inference.'
STAMP="$(date +%Y%m%d-%H%M%S%z)"

label="$(awk -v g="$GPU" 'BEGIN { x=g*100; if (x==int(x)) printf "%d", x; else printf "%.1f", x }' | sed 's/\.0$//; s/\./p/')"
ID="qwen35a3b-gpu${label}"
RUNDIR="${OUTROOT}/${ID}-${STAMP}"
mkdir -p "$RUNDIR"

memory_snapshot() {
  free -h
  swapon --show
  for f in /sys/class/drm/card*/device/mem_info_vram_{total,used} \
           /sys/class/drm/card*/device/mem_info_gtt_{total,used}; do
    [ -r "$f" ] && printf '%-55s %s\n' "$f" "$(cat "$f")"
  done
}

request() {
  curl -sS http://localhost:1234/api/v1/chat \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg model "$ID" --arg input "$PROMPT" '{model:$model,input:$input,reasoning:"off",temperature:0,max_output_tokens:256,store:false}')"
}

echo '=========================================='
echo 'Qwen 3.6 35B-A3B offload benchmark'
echo "GPU offload ratio: $GPU"
echo "Context:           $CTX"
echo "Identifier:        $ID"
echo '=========================================='

echo
echo '=== Unloading previous Qwen benchmark models ==='
lms ps 2>/dev/null | awk 'NR>1 && /qwen\/qwen3\.6-35b-a3b/ {print $1}' | while read -r old; do
  [ -n "$old" ] && lms unload "$old" || true
done

echo
echo "=== Estimate: ${GPU} GPU offload ==="
lms load "$MODEL" --gpu "$GPU" --context-length "$CTX" --parallel 1 --no-speculative-draft-mtp --estimate-only

echo
echo "=== Loading $ID ==="
lms load "$MODEL" --gpu "$GPU" --context-length "$CTX" --parallel 1 --no-speculative-draft-mtp --identifier "$ID" -y
lms ps

echo
echo '=== Pre-inference memory ==='
memory_snapshot

echo
echo '=== Warmup ==='
request | tee "$RUNDIR/warmup.json" | jq '{input_tokens:.stats.input_tokens,output_tokens:.stats.total_output_tokens,reasoning_tokens:.stats.reasoning_output_tokens,tokens_per_second:.stats.tokens_per_second,time_to_first_token_seconds:.stats.time_to_first_token_seconds}'

for i in 1 2 3; do
  echo
echo "Run $i:"
  request | tee "$RUNDIR/run-${i}.json" | jq '{input_tokens:.stats.input_tokens,output_tokens:.stats.total_output_tokens,reasoning_tokens:.stats.reasoning_output_tokens,tokens_per_second:.stats.tokens_per_second,time_to_first_token_seconds:.stats.time_to_first_token_seconds}'
  sleep 3
done

echo
echo '=== Post-inference memory ==='
memory_snapshot

jq -s '{runs:length,mean_tokens_per_second:(map(.stats.tokens_per_second)|add/length),min_tokens_per_second:(map(.stats.tokens_per_second)|min),max_tokens_per_second:(map(.stats.tokens_per_second)|max),mean_time_to_first_token_seconds:(map(.stats.time_to_first_token_seconds)|add/length),reasoning_tokens:(map(.stats.reasoning_output_tokens // 0)|add)}' "$RUNDIR"/run-*.json | tee "$RUNDIR/summary.json"

echo
echo "Saved benchmark: $RUNDIR"
