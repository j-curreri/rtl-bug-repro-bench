#!/usr/bin/env bash
# Serialized local-model runs on the RTX PRO 6000: GLM-5.3-Flash (FreeToken), then
# Qwen3.8-27B (SGLang). Local runs are capped by turns (60, same as Claude), not wall time.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
LOG=eval/runs/overnight.log
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
LOCAL_ARGS=(--skip-done --max-turns 60 --timeout 14400)

# --- GLM-5.3-Flash ---------------------------------------------------------------
while pgrep -f "run-id glm-pilot" >/dev/null; do sleep 60; done
mkdir -p eval/runs/glm1
P=$(ls -d eval/runs/glm-pilot/*-sim 2>/dev/null | head -1)
# Reuse the pilot only if it ended on its own (its wall limit was 1 h, not 4 h).
if [[ -n $P ]] && python3 -c "import json,sys;sys.exit(json.load(open('$P/result.json'))['agent_status']!='exited')" 2>/dev/null; then
  cp -r "$P" eval/runs/glm1/ && log "reused GLM pilot"
fi
log "GLM sim batch"; eval/run_batch.sh glm1 sim 1 --backend glm "${LOCAL_ARGS[@]}" >> "$LOG" 2>&1
log "GLM nosim batch"; eval/run_batch.sh glm1 nosim 1 --backend glm "${LOCAL_ARGS[@]}" >> "$LOG" 2>&1

# --- swap the GPU to SGLang --------------------------------------------------------
log "stopping FreeToken"; systemctl --user stop freetoken-glm; sleep 60
log "starting SGLang Qwen3.8-27B on :8096"
setsid nohup "$HOME/cve-recall-bench/serve-qwen-sglang.sh" > eval/runs/sglang-qwen.log 2>&1 < /dev/null &
ready(){ curl -sf --max-time 120 http://127.0.0.1:8096/v1/chat/completions -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer VLLM_API_KEY' -d '{"model":"qwen38-27b","messages":[{"role":"user","content":"Say OK"}],"max_tokens":64}' | grep -q '"choices"'; }
for i in $(seq 120); do ready && break; sleep 15; done
if ready; then
  log "Qwen sim batch";   eval/run_batch.sh qwen1 sim 4 --backend qwen "${LOCAL_ARGS[@]}" >> "$LOG" 2>&1
  log "Qwen nosim batch"; eval/run_batch.sh qwen1 nosim 4 --backend qwen "${LOCAL_ARGS[@]}" >> "$LOG" 2>&1
else
  log "SGLang never became ready; skipping Qwen"
fi
for pid in $(pgrep -f "sglang.launch_server"); do
  tr '\0' ' ' < /proc/$pid/cmdline | grep -q -- '--port 8096' && kill "$pid"
done
log "overnight done"
