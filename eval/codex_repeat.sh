#!/usr/bin/env bash
# Classifier repeatability: exact rerun of codex-full-s1 (high), then the same at xhigh.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
echo "[$(date '+%F %T')] start codex-full-s2 (high)"
eval/run_batch.sh codex-full-s2 sim 4 --backend codex --tier full --skip-done
echo "[$(date '+%F %T')] done codex-full-s2: $(grep -c 'valid=True' eval/runs/codex-full-s2/summary-sim.txt)/14"
echo "[$(date '+%F %T')] start codex-xhigh-full-s1"
RTLBENCH_CODEX_EFFORT=xhigh eval/run_batch.sh codex-xhigh-full-s1 sim 4 --backend codex --tier full --skip-done
echo "[$(date '+%F %T')] done codex-xhigh-full-s1: $(grep -c 'valid=True' eval/runs/codex-xhigh-full-s1/summary-sim.txt)/14"
