#!/usr/bin/env bash
# Run one condition over every case, N episodes at a time.
#   eval/run_batch.sh <run-id> <sim|nosim> [parallel] [extra run_episode.py args...]
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
RUN=$1; COND=$2; PAR=${3:-2}; shift 3 || shift $#
mkdir -p "$ROOT/eval/runs/$RUN"
ls -d "$ROOT"/cases/cva6-* | xargs -P "$PAR" -I{} sh -c \
  'python3 -I "$0"/eval/run_episode.py {} --condition '"$COND"' --run-id '"$RUN"' "$@" || echo "ERROR {}"' \
  "$ROOT" "$@" | tee -a "$ROOT/eval/runs/$RUN/summary-$COND.txt"
