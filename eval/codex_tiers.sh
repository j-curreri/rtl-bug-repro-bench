#!/usr/bin/env bash
# Codex CLI (ChatGPT subscription, gpt-6.1-sol, effort high): one sample per report tier, sim only.
# No turn cap (codex exec has none); the 40-min wall timeout is the only bound.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
for tier in full vague loc; do
  echo "[$(date '+%F %T')] start codex-$tier-s1"
  eval/run_batch.sh "codex-$tier-s1" sim 4 --backend codex --tier "$tier" --skip-done
  echo "[$(date '+%F %T')] done codex-$tier-s1: $(grep -c 'valid=True' eval/runs/codex-$tier-s1/summary-sim.txt)/14"
done
