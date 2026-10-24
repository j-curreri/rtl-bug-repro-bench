#!/usr/bin/env bash
# Queued after overnight2.sh: rerun Qwen3.8-27B (SGLang) sim+nosim as qwen2 with --effort xhigh
# (qwen1 is void: every request hit the chat template's reasoning-effort check). A one-turn
# Claude Code smoke request must succeed before the batches start.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
LOG=eval/runs/overnight.log
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

while kill -0 "${WAIT_PID:?}" 2>/dev/null; do sleep 60; done
log "after_glm: overnight2 finished"
systemctl --user stop freetoken-glm; sleep 60

log "starting SGLang Qwen3.8-27B on :8096"
setsid nohup "$HOME/cve-recall-bench/serve-qwen-sglang.sh" > eval/runs/sglang-qwen2.log 2>&1 < /dev/null &
ready_qwen(){ curl -sf --max-time 120 http://127.0.0.1:8096/v1/chat/completions -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer VLLM_API_KEY' -d '{"model":"qwen38-27b","messages":[{"role":"user","content":"Say OK"}],"max_tokens":64}' | grep -q '"choices"'; }
for i in $(seq 120); do ready_qwen && break; sleep 15; done

smoke(){ docker run --rm --network host \
  -e ANTHROPIC_BASE_URL=http://127.0.0.1:8096 -e ANTHROPIC_AUTH_TOKEN=VLLM_API_KEY \
  -e ANTHROPIC_MODEL=qwen38-27b -e ANTHROPIC_SMALL_FAST_MODEL=qwen38-27b \
  -e CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 rtlbench-agent:2.1.302 \
  claude -p "Reply with the word OK." --output-format json --max-turns 1 --effort xhigh 2>&1 \
  | tee eval/runs/qwen2-smoke.json | grep -q '"is_error":false'; }

if ready_qwen && smoke; then
  log "Qwen2 smoke OK; sim batch";  eval/run_batch.sh qwen2 sim 4 --backend qwen --skip-done --max-turns 60 --timeout 14400 >> "$LOG" 2>&1
  log "Qwen2 nosim batch";          eval/run_batch.sh qwen2 nosim 4 --backend qwen --skip-done --max-turns 60 --timeout 14400 >> "$LOG" 2>&1
else
  log "Qwen2 not started: SGLang not ready or smoke request failed (eval/runs/qwen2-smoke.json)"
fi
for pid in $(pgrep -f "sglang.launch_server"); do
  tr '\0' ' ' < /proc/$pid/cmdline | grep -q -- '--port 8096' && kill "$pid"
done
log "after_glm done"
