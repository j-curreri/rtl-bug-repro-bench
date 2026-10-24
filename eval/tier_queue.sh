#!/usr/bin/env bash
# API-backed queue: report tiers (vague, loc) and 3 samples per cell, Opus and Sonnet.
# Run ids: <model>-<tier>-s<k>; sample 1 of the full tier is batch1 (Sonnet) and opus1 (Opus).
# Stops if a batch looks void (usage limit or API errors: one-turn episodes or ERROR lines).
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
LOG=eval/runs/tier_queue.log
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
PAR=3
MODELS=${MODELS:-opus sonnet}  # e.g. MODELS=opus to run one model only

# An episode cut off by the usage limit (or an API error) is void, not a miss: delete it so
# --skip-done reruns it.
void_eps(){ grep -lE "hit your (session|weekly) limit|\"api_error_status\":[0-9]" eval/runs/"$1"/*-"$2"/transcript.jsonl 2>/dev/null; }

batch(){ # model tier sample condition
  local run="$1-$2-s$3" model=$1 tier=$2 cond=$4
  for t in $(void_eps "$run" "$cond"); do rm -rf "$(dirname "$t")"; done
  log "start $run $cond"
  eval/run_batch.sh "$run" "$cond" "$PAR" --model "$model" --tier "$tier" --skip-done >> "$LOG" 2>&1
  local f="eval/runs/$run/summary-$cond.txt"
  local bad; bad=$(void_eps "$run" "$cond" | wc -l)
  local ok; ok=$(grep -l '"valid": true' eval/runs/"$run"/*-"$cond"/result.json 2>/dev/null | wc -l)
  log "done $run $cond: $ok/14 valid, $bad void"
  if [ "$bad" -ge 3 ]; then log "STOP: $run looks void (usage limit or API errors)"; exit 1; fi
}

for m in $MODELS; do for t in vague loc; do batch $m $t 1 sim; done; done
for k in 2 3; do for m in $MODELS; do for c in sim nosim; do batch $m full $k $c; done; done; done
for k in 2 3; do for m in $MODELS; do for t in vague loc; do batch $m $t $k sim; done; done; done
log "tier queue done"
