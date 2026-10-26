#!/usr/bin/env bash
# Antigravity queue (2026-10-25): wait for the Gemini 3.8 Flash full batch, then Gemini 4 Argon (high)
# 1 sample each of full, vague, loc (run ids gemini-argon-<tier>-s1). One batch at a time; stop when a
# batch has 3+ episodes that ended in an agy ERROR (quota/limit or API failure), so a limit never burns
# the next batch.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
LOG=eval/runs/gemini_queue.log
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
errors(){ python3 -I - "$1" <<'PY'
import glob,json,sys
for f in sorted(glob.glob(f"eval/runs/{sys.argv[1]}/case-*/result.json")):
    d=json.load(open(f))
    if d.get("agy_status")!="SUCCESS":
        t=open(f.replace("result.json","transcript.jsonl"),errors="ignore").read()
        i=t.find('"error"'); print(d["case"], d.get("agy_status"), t[i:i+150].replace("\n"," ") if i>=0 else t[-150:].replace("\n"," "))
PY
}
log "waiting for the Gemini Flash full batch"
while pgrep -f 'run_batch[.]sh gemini-flash-full-s1' >/dev/null; do sleep 60; done
export RTLBENCH_AGY_MODEL=gemini-4-argon-high
for t in full vague loc; do
  run=gemini-argon-$t-s1
  log "start $run"
  eval/run_batch.sh "$run" sim 4 --backend gemini --tier "$t" --skip-done
  bad=$(errors "$run")
  log "done $run: $(grep -c 'valid=True' eval/runs/$run/summary-sim.txt)/14 valid, $(echo -n "$bad" | grep -c .) agy errors"
  [ -n "$bad" ] && echo "$bad" | tee -a "$LOG"
  if [ "$(echo -n "$bad" | grep -c .)" -ge 3 ]; then log "STOP: $run looks limited"; exit 1; fi
done
log "gemini queue done"
