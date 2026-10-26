#!/usr/bin/env bash
# Rerun Gemini 3.8 Flash (high) episodes voided by an Antigravity quota ("Individual quota reached"),
# on the paid account (default RTLBENCH_AGY_TOKEN): vague-s1 (all 14 voided on the free account), then
# loc-s1 (8 voided). One batch at a time; stop when a batch ends with 3+ agy errors (quota again).
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
LOG=eval/runs/gemini_flash.log
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
unset RTLBENCH_AGY_TOKEN
export RTLBENCH_AGY_MODEL=gemini-3.8-flash-high
for t in vague loc; do
  run=gemini-flash-$t-s1
  n=0; for f in eval/runs/$run/case-*/transcript.jsonl; do
    grep -q "Individual quota reached" "$f" && { rm -rf "$(dirname "$f")"; n=$((n+1)); }
  done
  log "start $run rerun ($n quota-voided episodes deleted)"
  eval/run_batch.sh "$run" sim 4 --backend gemini --tier "$t" --skip-done >> "$LOG" 2>&1
  bad=$(grep -l '"agy_status": "ERROR"' eval/runs/$run/case-*/result.json 2>/dev/null | wc -l)
  ok=$(python3 -I -c "import json,glob;print(sum(bool(json.load(open(f))['grade'].get('valid')) for f in glob.glob('eval/runs/$run/case-*/result.json')))")
  log "done $run: $ok/14 valid, $bad agy errors"
  if [ "$bad" -ge 3 ]; then log "STOP: $run looks limited"; exit 1; fi
done
log "gemini flash reruns done"
