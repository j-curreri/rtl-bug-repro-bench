#!/usr/bin/env bash
# Queued after qwen_samples.sh: serve Granite 4.2 8B on the RTX PRO 6000 (eval/serve_granite.sh),
# run eval/run_granite.sh granite1 (tool smoke, then sim+nosim), then stop the Granite server.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
LOG=eval/runs/overnight.log
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
port_pids(){ for pid in $(pgrep -f "sglang.launch_server"); do
  tr '\0' ' ' < /proc/$pid/cmdline | grep -q -- "--port $1" && echo "$pid"; done; }

while kill -0 "${WAIT_PID:?}" 2>/dev/null; do sleep 60; done
log "after_qwen: qwen_samples finished"
for pid in $(port_pids 8096); do kill "$pid"; done
# serve_granite.sh refuses to start while GPU 0 holds a >1 GiB compute process.
for i in $(seq 60); do
  nvidia-smi -i 0 --query-compute-apps=used_memory --format=csv,noheader,nounits \
    | awk '$1 > 1024 {busy=1} END {exit busy}' && break; sleep 10; done

log "starting Granite 4.2 8B on :8097"
setsid nohup bash eval/serve_granite.sh > eval/runs/sglang-granite.log 2>&1 < /dev/null &
for i in $(seq 240); do curl -sf --max-time 5 http://127.0.0.1:8097/health >/dev/null && break; sleep 10; done
sleep 30
if curl -sf --max-time 5 http://127.0.0.1:8097/health >/dev/null; then
  log "Granite ready; run_granite.sh granite1"
  bash eval/run_granite.sh granite1 >> eval/runs/granite1.log 2>&1 \
    && log "granite1 done: sim $(grep -c valid=True eval/runs/granite1/summary-sim.txt)/14, nosim $(grep -c valid=True eval/runs/granite1/summary-nosim.txt)/14" \
    || log "run_granite.sh failed (see eval/runs/granite1.log, eval/runs/granite1-smoke.jsonl)"
else
  log "Granite server never became healthy (eval/runs/sglang-granite.log)"
fi
for pid in $(port_pids 8097); do kill "$pid"; done
log "after_qwen done; Granite server stopped"
