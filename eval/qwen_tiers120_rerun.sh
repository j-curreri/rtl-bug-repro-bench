#!/usr/bin/env bash
# Rerun of qwen_tiers120.sh after the in-container sim fix (2026-10-22): the first qwen120-*-s1
# runs had no working sim/run.sh (libfesvr.so not found); they are in eval/runs/_brokensim-20261022.
# Reuses the SGLang server on :8096 if it is up.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
LOG=eval/runs/qwen_samples.log
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
stop_sglang(){ for pid in $(pgrep -f "sglang.launch_server"); do
  tr '\0' ' ' < /proc/$pid/cmdline | grep -q -- '--port 8096' && kill "$pid"; done; }

if ! curl -sf --max-time 5 http://127.0.0.1:8096/health >/dev/null; then
  log "starting SGLang"
  setsid nohup "$HOME/cve-recall-bench/serve-qwen-sglang.sh" > eval/runs/sglang-qwen-tiers120.log 2>&1 < /dev/null &
  for i in $(seq 240); do curl -sf --max-time 5 http://127.0.0.1:8096/health >/dev/null && break; sleep 10; done
  sleep 30
fi

for t in vague loc; do
  log "start qwen120-$t-s1 sim (rerun, sim fixed)"
  eval/run_batch.sh qwen120-$t-s1 sim 4 --backend qwen --tier $t --skip-done --max-turns 120 --timeout 21600 >> "$LOG" 2>&1
  log "done qwen120-$t-s1 sim: $(grep -c 'valid=True' eval/runs/qwen120-$t-s1/summary-sim.txt)/14"
done
stop_sglang
log "qwen 120-turn tiers rerun done; SGLang stopped"
