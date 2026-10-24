#!/usr/bin/env bash
# Build a CVA6 Verilator simulator, optionally with one case's bug.patch applied.
#   TARGET=<config> scripts/cva6_build.sh fixed   -> builds/<config>/cva6-fixed/Variane_testharness
#   scripts/cva6_build.sh cases/cva6-<sha>        -> builds/<config>/cva6-<sha>/Variane_testharness
# A case's config comes from its `target` file (default cv64a6_imafdc_sv39).
# MAKE_EXTRA adds make variables (e.g. TRACE_FAST=1 for VCD); NAME_SUFFIX keeps such builds apart.
# The variant tree copies CVA6's sources and symlinks the large verif/ and tools/ dirs,
# which the build only reads.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=$ROOT/cores/cva6
source "$ROOT/env.sh"

if [[ $1 == fixed ]]; then
  NAME=cva6-fixed; PATCH=
else
  CASE=$(cd "$1" && pwd); NAME=$(basename "$CASE"); PATCH=$CASE/bug.patch
  [[ -f $CASE/target ]] && TARGET=$(cat "$CASE/target")
fi
TARGET=${TARGET:-cv64a6_imafdc_sv39}
OUT=$ROOT/builds/$TARGET/$NAME${NAME_SUFFIX:-}
WORK=$OUT/tree

rm -rf "$WORK"
mkdir -p "$WORK"
rsync -a --exclude .git --exclude work-ver --exclude verif --exclude tools --exclude docs "$SRC/" "$WORK/"
ln -s "$SRC/verif" "$WORK/verif"
ln -s "$SRC/tools" "$WORK/tools"
# Benchmark-specific configs (not upstream) live in harness/cva6/configs.
cp "$ROOT"/harness/cva6/configs/*_config_pkg.sv "$WORK/core/include/"
if [[ -n $PATCH ]]; then
  (cd "$WORK" && patch -p1 --quiet < "$PATCH")
fi
# EXTRA_PATCH: an experimental RTL change applied on top (e.g. a candidate upstream fix).
if [[ -n ${EXTRA_PATCH:-} ]]; then
  (cd "$WORK" && patch -p1 --quiet < "$EXTRA_PATCH")
fi

# CVA6 pins Verilator v5.008; newer releases reject code in its vendored AXI IP.
VERILATOR_DIR=${VERILATOR_DIR:-$HOME/tools/oss-cad-2023-03-05/oss-cad-suite}
export RISCV=$SRC/tools/spike SPIKE_INSTALL_DIR=$SRC/tools/spike VERILATOR_INSTALL_DIR=$VERILATOR_DIR
(cd "$WORK" && make verilate target="$TARGET" -j"${JOBS:-16}" verilator_threads=1 \
   verilator="$VERILATOR_DIR/bin/verilator" ${MAKE_EXTRA:-}) > "$OUT/build.log" 2>&1
cp "$WORK/work-ver/Variane_testharness" "$OUT/Variane_testharness"
rm -rf "$WORK/work-ver"
echo "$OUT/Variane_testharness"
