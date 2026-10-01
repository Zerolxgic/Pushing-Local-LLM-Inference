#!/usr/bin/env bash
set -euo pipefail

CTX="${1:-16384}"
OCCUPANCY="${2:-90}"
MODEL="google/gemma-4-12b-qat"
GPU="max"
ID="gemma12b-workload-ctx${CTX}"
TARGET=$(( CTX * OCCUPANCY / 100 ))
OUTROOT="raw-results/gemma-phase-3"
STAMP="$(date +%Y%m%d-%H%M%S%z)"
RUNDIR="${OUTROOT}/${ID}-${STAMP}"
PROMPT_FILE="$RUNDIR/prompt.txt"
PAYLOAD="$RUNDIR/payload.json"
RESULT="$RUNDIR/result.json"
mkdir -p "$RUNDIR"

read_counter() {
  local pattern="$1"
  for f in $pattern; do
    [ -r "$f" ] && { cat "$f"; return; }
  done
  echo 0
}

memory_snapshot() {
  free -h
  swapon --show
  for f in /sys/class/drm/card*/device/mem_info_vram_{total,used} \
           /sys/class/drm/card*/device/mem_info_gtt_{total,used}; do
    [ -r "$f" ] && printf '%-55s %s\n' "$f" "$(cat "$f")"
  done
}

make_prompt() {
  local reps="$1"
  awk -v n="$reps" 'BEGIN {
    for (i=1;i<=n;i++) printf "Local inference moves model data through the memory hierarchy while the processor evaluates the current token. ";
    print "Summarize the main technical point in two concise sentences."
  }' > "$PROMPT_FILE"
}

make_payload() {
  local maxout="$1"
  jq -n --arg model "$ID" --rawfile input "$PROMPT_FILE" --argjson maxout "$maxout" \
    '{model:$model,input:$input,temperature:0,max_output_tokens:$maxout,store:false}' > "$PAYLOAD"
}

api_call() {
  curl -sS http://localhost:1234/api/v1/chat -H 'Content-Type: application/json' --data-binary @"$PAYLOAD"
}

echo '=========================================='
echo 'Gemma 4 12B QAT occupied-context workload'
echo "Configured context: $CTX"
echo "Target input:       ~$TARGET tokens"
echo "Target occupancy:   ${OCCUPANCY}%"
echo '=========================================='

echo
echo '=== Unloading previous Gemma benchmark models ==='
lms ps 2>/dev/null | awk 'NR>1 && /google\/gemma-4-12b-qat/ {print $1}' | while read -r old; do
  [ -n "$old" ] && lms unload "$old" || true
done

echo
echo '=== Loading calibration model ==='
lms load "$MODEL" --gpu "$GPU" --context-length "$CTX" --parallel 1 --no-speculative-draft-mtp --identifier "$ID" -y

reps=$(( TARGET / 30 ))
[ "$reps" -lt 1 ] && reps=1
observed=0

for pass in 1 2 3; do
  make_prompt "$reps"
  make_payload 1
  CAL="$(api_call)"
  printf '%s\n' "$CAL" > "$RUNDIR/calibration-pass-${pass}.json"
  observed="$(jq -r '.stats.input_tokens // 0' <<<"$CAL")"
  if [ "$observed" -le 0 ]; then
    echo 'Calibration failed:'
    jq . <<<"$CAL"
    exit 1
  fi
  echo "Pass $pass: reps=$reps observed_input_tokens=$observed"
  delta=$(( observed > TARGET ? observed - TARGET : TARGET - observed ))
  [ "$delta" -le 96 ] && break
  reps=$(( reps * TARGET / observed ))
  [ "$reps" -lt 1 ] && reps=1
done

echo
echo 'Calibration complete:'
echo "  target input tokens:   $TARGET"
echo "  observed input tokens: $observed"
echo "  repetitions:           $reps"

echo
echo '=== Reloading clean model for measured run ==='
lms unload "$ID"
lms load "$MODEL" --gpu "$GPU" --context-length "$CTX" --parallel 1 --no-speculative-draft-mtp --identifier "$ID" -y
lms ps

echo
echo '=== Pre-inference memory ==='
memory_snapshot
VRAM_BEFORE="$(read_counter '/sys/class/drm/card*/device/mem_info_vram_used')"
GTT_BEFORE="$(read_counter '/sys/class/drm/card*/device/mem_info_gtt_used')"

make_prompt "$reps"
make_payload 128
START_NS="$(date +%s%N)"
api_call > "$RESULT"
END_NS="$(date +%s%N)"
WALL="$(awk -v s="$START_NS" -v e="$END_NS" 'BEGIN {printf "%.3f",(e-s)/1000000000}')"
VRAM_AFTER="$(read_counter '/sys/class/drm/card*/device/mem_info_vram_used')"
GTT_AFTER="$(read_counter '/sys/class/drm/card*/device/mem_info_gtt_used')"

echo
echo '=== Inference result ==='
jq '{input_tokens:.stats.input_tokens,output_tokens:.stats.total_output_tokens,tokens_per_second:.stats.tokens_per_second,time_to_first_token_seconds:.stats.time_to_first_token_seconds}' "$RESULT"

echo
echo '=== Post-inference memory ==='
memory_snapshot

jq -n \
  --argjson configured_context "$CTX" \
  --argjson target_input_tokens "$TARGET" \
  --argjson actual_input_tokens "$(jq -r '.stats.input_tokens' "$RESULT")" \
  --argjson output_tokens "$(jq -r '.stats.total_output_tokens' "$RESULT")" \
  --argjson decode_tps "$(jq -r '.stats.tokens_per_second' "$RESULT")" \
  --argjson ttft "$(jq -r '.stats.time_to_first_token_seconds' "$RESULT")" \
  --arg wall "$WALL" \
  --argjson vram_before "$VRAM_BEFORE" --argjson vram_after "$VRAM_AFTER" \
  --argjson gtt_before "$GTT_BEFORE" --argjson gtt_after "$GTT_AFTER" \
  '{configured_context:$configured_context,target_input_tokens:$target_input_tokens,actual_input_tokens:$actual_input_tokens,context_occupancy_percent:(($actual_input_tokens/$configured_context)*10000|round)/100,output_tokens:$output_tokens,decode_tokens_per_second:$decode_tps,time_to_first_token_seconds:$ttft,total_request_wall_seconds:($wall|tonumber),vram_before_bytes:$vram_before,vram_after_bytes:$vram_after,vram_delta_bytes:($vram_after-$vram_before),gtt_before_bytes:$gtt_before,gtt_after_bytes:$gtt_after,gtt_delta_bytes:($gtt_after-$gtt_before)}' | tee "$RUNDIR/summary.json"

echo
echo "Saved occupied-context benchmark: $RUNDIR"
