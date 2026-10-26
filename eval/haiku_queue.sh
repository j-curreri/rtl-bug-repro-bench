#!/usr/bin/env bash
# Haiku 5.5 (Claude Code, default effort, sim): 3 samples of every tier, run ids haiku-<tier>-s<k>.
# One batch of 14 at a time, sample by sample, so a usage limit still leaves every tier sampled.
# Void episodes (usage limit or API error) are deleted so --skip-done reruns them; stop if a batch has 3+.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
LOG=eval/runs/haiku_queue.log
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
void_eps(){ grep -lE "hit your (session|weekly) limit|\"api_error_status\":[0-9]" eval/runs/"$1"/*-sim/transcript.jsonl 2>/dev/null; }
for k in 1 2 3; do for t in full vague loc; do
  run=haiku-$t-s$k
  for f in $(void_eps "$run"); do rm -rf "$(dirname "$f")"; done
  log "start $run"
  eval/run_batch.sh "$run" sim 3 --model haiku --tier "$t" --skip-done >> "$LOG" 2>&1
  bad=$(void_eps "$run" | wc -l)
  ok=$(grep -l '"valid": true' eval/runs/"$run"/*-sim/result.json 2>/dev/null | wc -l)
  log "done $run: $ok/14 valid, $bad void"
  if [ "$bad" -ge 3 ]; then log "STOP: $run looks void (usage limit or API errors)"; exit 1; fi
done; done
log "haiku queue done"
