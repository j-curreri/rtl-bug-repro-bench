#!/usr/bin/env bash
# Qwen3.8-27B full-tier samples 2 and 3 (sample 1 is qwen2), then one sim batch with a 120-turn
# cap to test whether the 60-turn cap explains sim (6/14) < nosim (9/14).
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
LOG=eval/runs/qwen_samples.log
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
stop_sglang(){ for pid in $(pgrep -f "sglang.launch_server"); do
  tr '\0' ' ' < /proc/$pid/cmdline | grep -q -- '--port 8096' && kill "$pid"; done; }

log "starting SGLang"
setsid nohup "$HOME/cve-recall-bench/serve-qwen-sglang.sh" > eval/runs/sglang-qwen-samples.log 2>&1 < /dev/null &
for i in $(seq 240); do curl -sf --max-time 5 http://127.0.0.1:8096/health >/dev/null && break; sleep 10; done
sleep 30
smoke(){ docker run --rm --network host \
  -e ANTHROPIC_BASE_URL=http://127.0.0.1:8096 -e ANTHROPIC_AUTH_TOKEN=VLLM_API_KEY \
  -e ANTHROPIC_MODEL=qwen38-27b -e ANTHROPIC_SMALL_FAST_MODEL=qwen38-27b \
  -e CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 rtlbench-agent:2.1.302 \
  claude -p "Reply with the word OK." --output-format json --max-turns 1 --effort xhigh \
  > eval/runs/qwen-samples-smoke.json 2>&1; grep -q '"is_error":false' eval/runs/qwen-samples-smoke.json; }
ok=0; for i in 1 2 3 4 5; do smoke && { ok=1; break; }; sleep 60; done
if [ $ok = 0 ]; then log "smoke failed (eval/runs/qwen-samples-smoke.json)"; stop_sglang; exit 1; fi

for k in 2 3; do for c in sim nosim; do
  log "start qwen-full-s$k $c"
  eval/run_batch.sh qwen-full-s$k $c 4 --backend qwen --skip-done --max-turns 60 --timeout 14400 >> "$LOG" 2>&1
  log "done qwen-full-s$k $c: $(grep -c 'valid=True' eval/runs/qwen-full-s$k/summary-$c.txt)/14"
done; done
log "start qwen-turns120 sim"
eval/run_batch.sh qwen-turns120 sim 4 --backend qwen --skip-done --max-turns 120 --timeout 21600 >> "$LOG" 2>&1
log "done qwen-turns120 sim: $(grep -c 'valid=True' eval/runs/qwen-turns120/summary-sim.txt)/14"
stop_sglang
log "qwen samples done; SGLang stopped"
