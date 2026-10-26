#!/usr/bin/env bash
# Claude Opus 5.5 (high) through Antigravity on the 3 cases where Opus hit Anthropic's classifier under
# Claude Code (6fe7b95910, 9a0e01e383, 2d2d0c11b7): full report, sim, 3 samples (run ids agy-opus-full-s<k>).
# Asks whether the classifier stops follow the model or the provider path (Antigravity -> Google).
# Starts after eval/gemini_queue.sh exits; Opus has its own Antigravity limit, so it runs either way.
# Stops if 2+ episodes in a sample hit the Antigravity quota; content-safety ERRORs are results, not limits.
# Usage: eval/agy_opus.sh [samples...]  (default 1 2 3)
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
LOG=eval/runs/agy_opus.log
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
log "waiting for gemini_queue.sh"
while pgrep -f 'gemini_queue[.]sh' >/dev/null; do sleep 60; done
export RTLBENCH_AGY_MODEL=claude-opus-5-5-high
for k in ${@:-1 2 3}; do
  run=agy-opus-full-s$k
  log "start $run"; mkdir -p "eval/runs/$run"
  printf '%s\n' cases/cva6-6fe7b95910 cases/cva6-9a0e01e383 cases/cva6-2d2d0c11b7 | xargs -P 3 -I{} \
    python3 -I eval/run_episode.py {} --condition sim --run-id "$run" --backend gemini --tier full --skip-done \
    | tee -a "eval/runs/$run/summary-sim.txt"
  err=$(grep -l '"agy_status": "ERROR"' eval/runs/$run/case-*/result.json 2>/dev/null | wc -l)
  bad=$(grep -l 'Individual quota reached' eval/runs/$run/case-*/transcript.jsonl 2>/dev/null | wc -l)
  log "done $run: $(grep -l '"valid": true' eval/runs/$run/case-*/result.json 2>/dev/null | wc -l)/3 valid, $err agy errors, $bad quota"
  if [ "$bad" -ge 2 ]; then log "STOP: $run looks limited"; exit 1; fi
done
log "agy opus done"
