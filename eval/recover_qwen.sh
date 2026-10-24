#!/usr/bin/env bash
# Resume the Qwen-only batches after the reasoning-effort compatibility fix.
set -euo pipefail
cd /home/bob/Downloads/rtl-bug-repro-bench
for ((i=0; i<120; i++)); do
  if curl -sf --max-time 5 http://127.0.0.1:8096/health >/dev/null; then break; fi
  sleep 5
done
curl -sf --max-time 5 http://127.0.0.1:8096/health >/dev/null
docker run --rm --network host \
  -e ANTHROPIC_BASE_URL=http://127.0.0.1:8096 -e ANTHROPIC_AUTH_TOKEN=VLLM_API_KEY \
  -e ANTHROPIC_MODEL=qwen38-27b -e ANTHROPIC_SMALL_FAST_MODEL=qwen38-27b \
  -e CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 rtlbench-agent:2.1.302 \
  claude -p 'Reply with the word OK.' --output-format json --max-turns 1 --effort xhigh \
  > eval/runs/qwen2-recovery-smoke.json 2>&1
grep -q '"is_error":false' eval/runs/qwen2-recovery-smoke.json
echo "[$(date '+%F %T')] Qwen2 recovery smoke OK; sim batch"
eval/run_batch.sh qwen2 sim 4 --backend qwen --skip-done --max-turns 60 --timeout 14400
echo "[$(date '+%F %T')] Qwen2 nosim batch"
eval/run_batch.sh qwen2 nosim 4 --backend qwen --skip-done --max-turns 60 --timeout 14400
echo "[$(date '+%F %T')] Qwen2 recovery done"
