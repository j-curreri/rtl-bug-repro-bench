#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
bash eval/serve_granite.sh >> eval/runs/sglang-granite.log 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT
ready=0
for ((i=0;i<240;i++)); do
  if curl -fsS --max-time 5 http://127.0.0.1:8097/health >/dev/null 2>&1; then ready=1; break; fi
  if ! kill -0 "$server_pid" 2>/dev/null; then echo 'Granite server exited during startup'; exit 1; fi
  sleep 5
done
if (( ! ready )); then echo 'Granite readiness timed out'; exit 1; fi
echo "[$(date -Is)] Granite healthy; resuming granite1"
bash eval/run_granite.sh granite1 >> eval/runs/granite1.log 2>&1
echo "[$(date -Is)] Granite run finished"
