#!/usr/bin/env bash
# Takes over from overnight.sh after its GLM sim batch: Qwen3.8-27B (SGLang) sim+nosim first,
# then GLM-5.3-Flash nosim. Same caps as overnight.sh: 60 turns, 4 h wall per episode.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
LOG=eval/runs/overnight.log
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
LOCAL_ARGS=(--skip-done --max-turns 60 --timeout 14400)

while pgrep -f "run-id glm1 .*--backend glm|run_batch.sh glm1 sim" >/dev/null; do sleep 60; done
log "GLM sim batch finished (overnight2 takes over)"

log "stopping FreeToken"; systemctl --user stop freetoken-glm; sleep 60
log "starting SGLang Qwen3.8-27B on :8096"
setsid nohup "$HOME/cve-recall-bench/serve-qwen-sglang.sh" > eval/runs/sglang-qwen.log 2>&1 < /dev/null &
ready_qwen(){ curl -sf --max-time 120 http://127.0.0.1:8096/v1/chat/completions -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer VLLM_API_KEY' -d '{"model":"qwen38-27b","messages":[{"role":"user","content":"Say OK"}],"max_tokens":64}' | grep -q '"choices"'; }
for i in $(seq 120); do ready_qwen && break; sleep 15; done
if ready_qwen; then
  log "Qwen sim batch";   eval/run_batch.sh qwen1 sim 4 --backend qwen "${LOCAL_ARGS[@]}" >> "$LOG" 2>&1
  log "Qwen nosim batch"; eval/run_batch.sh qwen1 nosim 4 --backend qwen "${LOCAL_ARGS[@]}" >> "$LOG" 2>&1
else
  log "SGLang never became ready; skipping Qwen"
fi
for pid in $(pgrep -f "sglang.launch_server"); do
  tr '\0' ' ' < /proc/$pid/cmdline | grep -q -- '--port 8096' && kill "$pid"
done
sleep 60

log "starting FreeToken GLM-5.3-Flash"; systemctl --user start freetoken-glm
ready_glm(){ curl -sf --max-time 120 http://127.0.0.1:1919/v1/messages -H 'content-type: application/json' \
  -H 'x-api-key: freetoken' -H 'anthropic-version: 2023-06-01' \
  -d '{"model":"GLM-5.3-Flash-FTW","max_tokens":32,"messages":[{"role":"user","content":"Say OK"}]}' | grep -q '"content"'; }
for i in $(seq 120); do ready_glm && break; sleep 15; done
if ready_glm; then
  log "GLM nosim batch"; eval/run_batch.sh glm1 nosim 1 --backend glm "${LOCAL_ARGS[@]}" >> "$LOG" 2>&1
else
  log "FreeToken never became ready; skipping GLM nosim"
fi
log "stopping FreeToken"; systemctl --user stop freetoken-glm
log "overnight done"
