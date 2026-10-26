#!/usr/bin/env bash
# Codex GPT-6-Luna (effort high, sim): 3 samples of every tier. One batch of 14 at a time;
# after each batch, stop if any episode failed for a reason other than OpenAI's cyber classifier
# (usage/rate limit, API error, agent never started), so a limit never burns the next batch.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
LOG=eval/runs/codex_luna.log
export RTLBENCH_CODEX_MODEL=gpt-6-luna
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
check(){  # prints the non-classifier failures of one run, one per line
  python3 -I - "$1" <<'PY'
import glob,json,sys
for t in sorted(glob.glob(f"eval/runs/{sys.argv[1]}/case-*/transcript.jsonl")):
    s=open(t,errors="ignore").read(); bad=None
    msgs=[]
    for line in s.splitlines():
        try: e=json.loads(line)
        except json.JSONDecodeError: continue
        if e.get("type")=="turn.failed": msgs.append((e.get("error") or {}).get("message",""))
        if e.get("type")=="error": msgs.append(e.get("message",""))
    if any("cybersecurity risk" not in m for m in msgs): bad=[m for m in msgs if "cybersecurity risk" not in m][0][:150]
    elif '"turn.started"' not in s: bad="agent never started: "+s[:150].replace("\n"," ")
    if bad: print(t.split("/")[-2], bad)
PY
}
for run in luna-full-s1:full luna-vague-s1:vague luna-loc-s1:loc luna-full-s2:full luna-vague-s2:vague luna-loc-s2:loc luna-full-s3:full luna-vague-s3:vague luna-loc-s3:loc; do
  id=${run%%:*}; tier=${run##*:}
  log "start $id"
  eval/run_batch.sh "$id" sim 4 --backend codex --tier "$tier" --skip-done
  bad=$(check "$id")
  log "done $id: $(grep -c 'valid=True' eval/runs/$id/summary-sim.txt)/14"
  if [ -n "$bad" ]; then
    log "STOP: non-classifier failures in $id (rerun these after the limit resets):"
    echo "$bad" | tee -a "$LOG"
    exit 1
  fi
done
log "all Luna samples done"
