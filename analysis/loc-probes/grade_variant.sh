#!/usr/bin/env bash
# exp.sh <case> <test.S>: build and grade a variant on the case's fixed and buggy cores.
set -e
B=/mnt/k3/rtl-bug-repro-bench
source $B/env.sh >/dev/null 2>&1 || true
cd "$(dirname "$2")"
make -s -f $B/harness/cva6/Makefile TEST="$(basename "$2")" >/dev/null
python3 -I $B/scripts/grade.py $B/cases/$1 "build/$(basename "${2%.S}").elf" | python3 -I -c "import json,sys;d=json.load(sys.stdin);print('fixed',d['fixed'],'buggy',d['buggy'])"
