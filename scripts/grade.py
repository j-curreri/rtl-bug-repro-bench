"""Two-sided grading of a reproducer ELF for one CVA6 case.

A reproducer is valid only if it PASSES on the fixed core and does NOT pass on the buggy
core (it fails, traps unexpectedly, or times out). A test that fails or passes on both
scores zero, so a test cannot score just by always failing.

    python3 scripts/grade.py cases/cva6-<sha> path/to/test.elf
"""
import argparse
import json
import pathlib
import re
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAX_CYCLES = 2_000_000
WALL_TIMEOUT_S = 300


def run(sim: pathlib.Path, elf: pathlib.Path) -> dict:
    # The testharness writes trace files to its cwd; keep parallel runs apart.
    with tempfile.TemporaryDirectory(prefix="grade-") as cwd:
        try:
            p = subprocess.run([str(sim), f"+max-cycles={MAX_CYCLES}", str(elf)],
                               capture_output=True, text=True, timeout=WALL_TIMEOUT_S, cwd=cwd)
        except subprocess.TimeoutExpired:
            return {"outcome": "timeout", "tohost": None}
    out = p.stdout + p.stderr
    if "*** SUCCESS ***" in out:
        return {"outcome": "pass", "tohost": 0}
    m = re.search(r"\*\*\* FAILED \*\*\* \(tohost = (\d+).*?after (\d+) cycles", out)
    if m and int(m.group(2)) >= MAX_CYCLES:
        return {"outcome": "timeout", "tohost": None}
    if m:
        return {"outcome": "fail", "tohost": int(m.group(1))}
    return {"outcome": "timeout" if "max" in out.lower() else "error", "tohost": None,
            "tail": out[-500:]}


def target_of(case: pathlib.Path) -> str:
    t = case / "target"
    return t.read_text().strip() if t.exists() else "cv64a6_imafdc_sv39"


def grade(case: pathlib.Path, elf: pathlib.Path) -> dict:
    builds = ROOT / "builds" / target_of(case)
    # cases/<case>/reference names another fixed build (e.g. HEAD + an unrelated upstream fix).
    ref = case / "reference"
    fixed_dir = ref.read_text().strip() if ref.exists() else "cva6-fixed"
    fixed = run(builds / fixed_dir / "Variane_testharness", elf)
    buggy = run(builds / case.name / "Variane_testharness", elf)
    return {"case": case.name, "elf": str(elf), "fixed": fixed, "buggy": buggy,
            "valid": fixed["outcome"] == "pass" and buggy["outcome"] != "pass"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("case", type=pathlib.Path)
    ap.add_argument("elf", type=pathlib.Path)
    a = ap.parse_args()
    print(json.dumps(grade(a.case.resolve(), a.elf.resolve()), indent=2))


if __name__ == "__main__":
    main()
