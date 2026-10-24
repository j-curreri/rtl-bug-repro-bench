#!/usr/bin/env bash
# Requires a separately started Granite server. Never stops another server.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
RUN=${1:-granite1}
mkdir -p eval/runs
curl -fsS --max-time 10 http://127.0.0.1:8097/health >/dev/null
docker run --rm --network host \
  -e ANTHROPIC_BASE_URL=http://127.0.0.1:8097 -e ANTHROPIC_AUTH_TOKEN=rtlbench-granite \
  -e ANTHROPIC_MODEL=granite-4.2-8b -e ANTHROPIC_SMALL_FAST_MODEL=granite-4.2-8b \
  -e CLAUDE_CODE_MAX_CONTEXT_TOKENS="${GRANITE_CONTEXT:-131072}" \
  -e CLAUDE_CODE_MAX_OUTPUT_TOKENS="${GRANITE_SMOKE_OUTPUT_TOKENS:-32000}" \
  -e CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 rtlbench-agent:2.1.302 \
  claude -p 'Use Bash to run printf GRANITE_TOOL_OK, then report its output.' \
  --output-format stream-json --verbose --max-turns 3 --permission-mode bypassPermissions \
  > "eval/runs/$RUN-smoke.jsonl" 2>&1
python3 - "$RUN" <<'PY'
import json, pathlib, sys
rows = [json.loads(line) for line in pathlib.Path(f"eval/runs/{sys.argv[1]}-smoke.jsonl").read_text().splitlines() if line.startswith('{')]
assert any(r.get('type') == 'result' and not r.get('is_error', True) for r in rows), 'Claude Code smoke failed'
assert any(b.get('type') == 'tool_use' and b.get('name') == 'Bash' for r in rows for b in r.get('message', {}).get('content', []) if isinstance(b, dict)), 'Smoke did not call Bash'
assert any(b.get('type') == 'tool_result' and not b.get('is_error', False) and 'GRANITE_TOOL_OK' in str(b.get('content', '')) for r in rows for b in r.get('message', {}).get('content', []) if isinstance(b, dict)), 'Smoke tool result missing'
print('Granite Claude Code tool smoke passed')
PY
if [[ ${GRANITE_SMOKE_ONLY:-0} == 1 ]]; then exit 0; fi
for condition in sim nosim; do
  eval/run_batch.sh "$RUN" "$condition" 4 --backend granite --skip-done --max-turns 60 --timeout 14400
done
