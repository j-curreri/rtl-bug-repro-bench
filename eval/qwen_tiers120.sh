#!/usr/bin/env bash
# Qwen3.8-27B vague and loc report tiers, sim, 120-turn cap (run ids qwen120-<tier>-s1).
# Waits for qwen_turns120_nosim.sh to finish so the two never share the server.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
LOG=eval/runs/qwen_samples.log
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
stop_sglang(){ for pid in $(pgrep -f "sglang.launch_server"); do
  tr '\0' ' ' < /proc/$pid/cmdline | grep -q -- '--port 8096' && kill "$pid"; done; }

while pgrep -f qwen_turns120_nosim.sh >/dev/null; do sleep 60; done
while pgrep -f "sglang.launch_server" >/dev/null; do sleep 10; done

log "starting SGLang"
setsid nohup "$HOME/cve-recall-bench/serve-qwen-sglang.sh" > eval/runs/sglang-qwen-tiers120.log 2>&1 < /dev/null &
for i in $(seq 240); do curl -sf --max-time 5 http://127.0.0.1:8096/health >/dev/null && break; sleep 10; done
sleep 30
smoke(){ docker run --rm --network host \
  -e ANTHROPIC_BASE_URL=http://127.0.0.1:8096 -e ANTHROPIC_AUTH_TOKEN=VLLM_API_KEY \
  -e ANTHROPIC_MODEL=qwen38-27b -e ANTHROPIC_SMALL_FAST_MODEL=qwen38-27b \
  -e CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 rtlbench-agent:2.1.302 \
  claude -p "Reply with the word OK." --output-format json --max-turns 1 --effort xhigh \
  > eval/runs/qwen-tiers120-smoke.json 2>&1; grep -q '"is_error":false' eval/runs/qwen-tiers120-smoke.json; }
ok=0; for i in 1 2 3 4 5; do smoke && { ok=1; break; }; sleep 60; done
if [ $ok = 0 ]; then log "smoke failed (eval/runs/qwen-tiers120-smoke.json)"; stop_sglang; exit 1; fi

for t in vague loc; do
  log "start qwen120-$t-s1 sim"
  eval/run_batch.sh qwen120-$t-s1 sim 4 --backend qwen --tier $t --skip-done --max-turns 120 --timeout 21600 >> "$LOG" 2>&1
  log "done qwen120-$t-s1 sim: $(grep -c 'valid=True' eval/runs/qwen120-$t-s1/summary-sim.txt)/14"
done
stop_sglang
log "qwen 120-turn tiers done; SGLang stopped"
