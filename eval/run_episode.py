"""Run one benchmark episode: headless Claude Code in a sandbox writes a reproducer for one case.

    python3 -I eval/run_episode.py cases/cva6-<sha> --condition sim --run-id r1 [--model opus]

Conditions:
  sim    the workspace includes the buggy simulator (sim/run.sh), so the model can iterate
  nosim  RTL, harness and bug report only; the model can compile but not simulate

The model sees an anonymized case id, the buggy RTL (no git history), the harness, and our
symptom-level report, never the upstream commit message, fixed RTL, or reference test.
Grading always uses the pristine harness in harness/cva6, not the workspace copy.
"""
import argparse
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import grade  # noqa: E402

IMAGE = "rtlbench-agent:2.1.302"
RISCV_GCC = pathlib.Path.home() / "tools/xpack-riscv-none-elf-gcc-15.2.0-1"
SPIKE_LIB = ROOT / "cores/cva6/tools/spike/lib"
TOKEN_FILE = pathlib.Path(os.environ.get("RTLBENCH_TOKEN_FILE", pathlib.Path.home() / ".config/rtlbench/token"))
HARNESS_FILES = ["crt.S", "test.h", "hyp.h", "link.ld", "Makefile"]
# Anything in a transcript that suggests reaching outside the sandbox or the answer key.
LEAK_RE = re.compile(r"https?://|github|\bgit\b|\bcurl\b|\bwget\b|openhwgroup|rtl-bug-repro-bench/cases", re.I)

TASK = """# Task: write a bug reproducer for a RISC-V core

`core/` holds the SystemVerilog RTL of a CVA6 RISC-V core, configuration `{config}`
(see `core/include/{config}_config_pkg.sv`). This core contains the bug described below.

Write a bare-metal RISC-V assembly program `repro.S` in this directory that
1. ends with PASS on a core that is correct according to the RISC-V specifications, and
2. does not end with PASS on this buggy core (FAIL, an unexpected trap, or a hang all count).

Grading runs your program on this core and on a corrected version of the same core. It
scores only if both conditions hold, so a program that always fails scores zero.

## Bug report

{report}

## Harness

- `harness/test.h`: execution starts in M-mode at `test_main` (you define it). End with the
  `PASS` or `FAIL(n)` macro. Define your own global `trap_handler` to handle traps; the
  default handler fails. Helpers: `PMP_ALLOW_ALL`, `ENTER_MODE(mpp, label)`.
- `harness/hyp.h`: hypervisor helpers (1 GiB-page G-stage and VS-stage tables, `ENTER_VS`).
- Build: `make -C harness TEST=$PWD/repro.S` -> `harness/build/repro.elf` (ISA rv64gc + H).
- Memory: DRAM at 0x80000000, CLINT at 0x02000000. Grading uses the harness exactly as
  provided, so do not rely on edits to `harness/`.
{sim_section}
## Rules

There is no internet access and no Python; the shell has the usual coreutils, sed, awk, grep and
make. Work only inside this directory. Finish by leaving `repro.S` here.
"""

SIM_SECTION = """
## Simulator

`sim/run.sh repro.S` builds your program and runs it on this buggy core (about 15 s).
It prints SUCCESS, FAILED (tohost = n) or TIMEOUT. The instruction trace of the last run is
in `sim/out/trace_hart_0.dasm`.
"""

RUN_SH = """#!/bin/sh
# Build a test and run it on this (buggy) core.
set -e
T=$(realpath "$1")
make -s -C /work/harness TEST="$T"
mkdir -p /work/sim/out && cd /work/sim/out && rm -f ./*.dasm ./*.traces
OUT=$(timeout 200 /work/sim/Variane_testharness +max-cycles=2000000 \\
      "/work/harness/build/$(basename "${T%.S}").elf" 2>&1 || true)
case "$OUT" in
  *"*** SUCCESS ***"*) echo SUCCESS ;;
  *"tohost = 2147483647"*) echo TIMEOUT ;;
  *"*** FAILED ***"*) echo "$OUT" | grep -o "FAILED \\*\\*\\* (tohost = [0-9]*)" | head -1 ;;
  *) echo "NO RESULT; simulator output ends with:"; echo "$OUT" | tail -3 ;;
esac
"""


def anon_id(case: pathlib.Path) -> str:
    return "case-" + hashlib.sha256(case.name.encode()).hexdigest()[:6]


REPORTS = {"full": "report.md", "vague": "report_vague.md", "loc": "report_loc.md"}


def build_workspace(case: pathlib.Path, ep: pathlib.Path, condition: str, tier: str = "full") -> pathlib.Path:
    target = grade.target_of(case)
    tree = ROOT / "builds" / target / case.name / "tree"
    if not tree.exists():
        raise SystemExit(f"missing buggy build tree {tree}; run scripts/cva6_build.sh {case}")
    ws = ep / "work"
    shutil.copytree(tree / "core", ws / "core", symlinks=False)
    (ws / "harness").mkdir()
    for f in HARNESS_FILES:
        shutil.copy(ROOT / "harness/cva6" / f, ws / "harness" / f)
    sim_section = ""
    if condition == "sim":
        (ws / "sim").mkdir()
        shutil.copy(ROOT / "builds" / target / case.name / "Variane_testharness", ws / "sim")
        (ws / "sim/run.sh").write_text(RUN_SH)
        (ws / "sim/run.sh").chmod(0o755)
        sim_section = SIM_SECTION
    (ws / "TASK.md").write_text(TASK.format(config=target, report=(case / REPORTS[tier]).read_text().strip(),
                                            sim_section=sim_section))
    return ws


# Local models are served by FreeToken's Anthropic-compatible API on the host loopback.
# Its real context is the KV reserve (ft-start.sh --kv-reserve-tokens), not the advertised 1M.
LOCAL_BACKENDS = {
    "glm": {"ANTHROPIC_BASE_URL": "http://127.0.0.1:1919", "ANTHROPIC_AUTH_TOKEN": "freetoken",
            "ANTHROPIC_MODEL": "GLM-5.3-Flash-FTW", "ANTHROPIC_SMALL_FAST_MODEL": "GLM-5.3-Flash-FTW",
            "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "131072",
            "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"},
    # SGLang (~/cve-recall-bench/serve-qwen-sglang.sh): --context-length 262144, --api-key VLLM_API_KEY.
    "qwen": {"ANTHROPIC_BASE_URL": "http://127.0.0.1:8096", "ANTHROPIC_AUTH_TOKEN": "VLLM_API_KEY",
             "ANTHROPIC_MODEL": "qwen38-27b", "ANTHROPIC_SMALL_FAST_MODEL": "qwen38-27b",
             "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "262144",
             "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"},
    "granite": {"ANTHROPIC_BASE_URL": "http://127.0.0.1:8097", "ANTHROPIC_AUTH_TOKEN": "rtlbench-granite",
                "ANTHROPIC_MODEL": "granite-4.2-8b", "ANTHROPIC_SMALL_FAST_MODEL": "granite-4.2-8b",
                "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "131072",
                "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"},
    # SGLang (eval/serve_nemotron.sh) on the RTX PRO 6000, NVFP4 weights.
    "nemotron": {"ANTHROPIC_BASE_URL": "http://127.0.0.1:8098", "ANTHROPIC_AUTH_TOKEN": "rtlbench-nemotron",
                 "ANTHROPIC_MODEL": "nemotron-3-super", "ANTHROPIC_SMALL_FAST_MODEL": "nemotron-3-super",
                 "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "131072",
                 "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"},
}
# Qwen3.8's chat template accepts reasoning effort xhigh (its default), medium or low; Claude
# Code's default "high" makes SGLang return HTTP 500 on every request (void run qwen1).
BACKEND_ARGS = {"qwen": ["--effort", "xhigh"]}
# Codex CLI on the ChatGPT subscription: the static binary is mounted into the same image, and
# each episode gets a private CODEX_HOME holding only a copy of auth.json (deleted afterwards).
# `codex exec` has no turn cap, so only the wall-clock timeout bounds an episode.
# The package dir holds codex plus helpers it spawns from its own bin/ (codex-code-mode-host).
CODEX_PKG = (pathlib.Path.home() / ".codex/packages/standalone/current").resolve()
CODEX_AUTH = pathlib.Path.home() / ".codex/auth.json"
CODEX_MODEL = os.environ.get("RTLBENCH_CODEX_MODEL", "gpt-6.1-sol")
CODEX_EFFORT = os.environ.get("RTLBENCH_CODEX_EFFORT", "high")
# Antigravity CLI (agy) on the user's Google account. On the desktop agy keeps its login in the OS
# keyring; in the container it falls back to a token file, made once by an interactive login with
# HOME=~/.rtlbench/agy-home. RTLBENCH_AGY_TOKEN picks another login, e.g. the free-tier account in
# ~/.rtlbench/agy-home2. Each episode gets a private HOME holding only a copy of that file
# (deleted afterwards). The binary is mounted read-only. Effort is part of
# the model name (gemini-4-argon-high). agy cannot switch off search_web in its settings, and global
# hooks load but never fire, so a workspace PreToolUse hook (mounted read-only over /work/.agents)
# denies the web and browser tools. Like codex exec, agy has no turn cap.
AGY_BIN = pathlib.Path.home() / ".local/bin/agy"
AGY_TOKEN = pathlib.Path(os.environ.get(
    "RTLBENCH_AGY_TOKEN", str(pathlib.Path.home() / ".rtlbench/agy-home/.gemini/antigravity-cli/antigravity-oauth-token"))).resolve()
AGY_MODEL = os.environ.get("RTLBENCH_AGY_MODEL", "gemini-4-argon-high")
AGY_NO_WEB = "^(search_web|read_url_content|open_browser_url|read_browser_page|browser_.*|capture_browser_.*|click_browser_pixel|execute_browser_javascript|list_browser_pages)$"


def run_agent(ws: pathlib.Path, ep: pathlib.Path, backend: str, model: str | None, max_turns: int,
              timeout_s: int) -> dict:
    name = f"rtlbench-{ep.parent.name}-{ep.name}"
    if backend == "codex":
        return run_codex(ws, ep, name, model, timeout_s)
    if backend == "gemini":
        return run_agy(ws, ep, name, model, timeout_s)
    if backend == "claude":
        # The subscription token reaches the container by name only (not on the command line).
        env = dict(os.environ, CLAUDE_CODE_OAUTH_TOKEN=TOKEN_FILE.read_text().strip())
        net, passthrough = [], ["CLAUDE_CODE_OAUTH_TOKEN"]
    else:
        # No Anthropic credentials at all, so a local run can never spend subscription usage.
        local = LOCAL_BACKENDS[backend]
        env = {k: v for k, v in os.environ.items() if not k.startswith(("ANTHROPIC_", "CLAUDE_CODE_OAUTH"))}
        env.update(local)
        net, passthrough = ["--network", "host"], list(local)
    cmd = ["docker", "run", "--rm", "--name", name, *net,
           "-v", f"{ws}:/work",
           "-v", f"{RISCV_GCC}:/opt/riscv:ro",
           # The simulators' RUNPATH names the old ~/Downloads checkout; give the lib a fixed path.
           "-v", f"{SPIKE_LIB}:/opt/spike-lib:ro",
           "-e", "LD_LIBRARY_PATH=/opt/spike-lib",
           *[a for k in passthrough for a in ("-e", k)],
           "-e", "PATH=/opt/riscv/bin:/usr/local/bin:/usr/bin:/bin",
           IMAGE, "claude", "-p", "Read TASK.md and complete the task.",
           "--output-format", "stream-json", "--verbose",
           "--max-turns", str(max_turns),
           "--permission-mode", "bypassPermissions",
           "--disallowedTools", "WebFetch", "WebSearch"]
    if model:
        cmd += ["--model", model]
    cmd += BACKEND_ARGS.get(backend, [])
    with open(ep / "transcript.jsonl", "w") as log:
        try:
            p = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, env=env, timeout=timeout_s)
            status = "exited" if p.returncode == 0 else f"exit {p.returncode}"
        except subprocess.TimeoutExpired:
            subprocess.run(["docker", "kill", name], capture_output=True)
            status = "wall timeout"
    return {"agent_status": status, **summarize_transcript(ep / "transcript.jsonl")}


def run_codex(ws: pathlib.Path, ep: pathlib.Path, name: str, model: str | None, timeout_s: int) -> dict:
    home = ep / "codex-home"
    home.mkdir()
    shutil.copy(CODEX_AUTH, home / "auth.json")
    (home / "auth.json").chmod(0o600)
    model = model or CODEX_MODEL
    cmd = ["docker", "run", "--rm", "--name", name,
           "-v", f"{ws}:/work",
           "-v", f"{RISCV_GCC}:/opt/riscv:ro",
           "-v", f"{SPIKE_LIB}:/opt/spike-lib:ro",
           "-v", f"{CODEX_PKG}:/opt/codex:ro",
           "-v", f"{home}:/codex-home",
           "-e", "CODEX_HOME=/codex-home",
           "-e", "LD_LIBRARY_PATH=/opt/spike-lib",
           "-e", "PATH=/opt/codex/bin:/opt/codex/codex-path:/opt/riscv/bin:/usr/local/bin:/usr/bin:/bin",
           IMAGE, "codex", "exec", "--json", "--dangerously-bypass-approvals-and-sandbox",
           "--skip-git-repo-check", "--ephemeral", "--ignore-user-config", "-C", "/work",
           "-m", model, "-c", f'model_reasoning_effort="{CODEX_EFFORT}"', "-c", 'web_search="disabled"',
           "Read TASK.md and complete the task."]
    t0 = time.time()
    try:
        with open(ep / "transcript.jsonl", "w") as log:
            try:
                p = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                   timeout=timeout_s)
                status = "exited" if p.returncode == 0 else f"exit {p.returncode}"
            except subprocess.TimeoutExpired:
                subprocess.run(["docker", "kill", name], capture_output=True)
                status = "wall timeout"
    finally:
        shutil.rmtree(home, ignore_errors=True)
    return {"agent_status": status, "model": model, "effort": CODEX_EFFORT,
            **summarize_codex(ep / "transcript.jsonl"), "duration_s": round(time.time() - t0, 3)}


def run_agy(ws: pathlib.Path, ep: pathlib.Path, name: str, model: str | None, timeout_s: int) -> dict:
    home = ep / "agy-home"
    (home / ".gemini/antigravity-cli").mkdir(parents=True)
    shutil.copy(AGY_TOKEN, home / ".gemini/antigravity-cli" / AGY_TOKEN.name)
    (home / ".gemini/antigravity-cli" / AGY_TOKEN.name).chmod(0o600)
    (home / ".gemini/antigravity-cli/settings.json").write_text(json.dumps(
        {"trustedWorkspaces": ["/work"], "permissions": {"deny": ["read_url(*)", "execute_url(*)"]}}))
    hooks = ep / "agy-hooks"
    hooks.mkdir()
    (hooks / "no-web.sh").write_text("#!/bin/sh\ncat > /dev/null\n"
                                     "echo '{\"decision\":\"deny\",\"reason\":\"Web access is disabled.\"}'\n")
    (hooks / "no-web.sh").chmod(0o755)
    (hooks / "hooks.json").write_text(json.dumps({"no-web": {"PreToolUse": [
        {"matcher": AGY_NO_WEB, "hooks": [{"type": "command", "command": "/work/.agents/no-web.sh", "timeout": 10}]}]}}))
    (ws / ".agents").mkdir()
    # agy runs commands on a pty. Plain `timeout` puts the simulator in a background process group,
    # where the tty stops it (state T) before the 200 s limit can fire, so every run hung.
    run_sh = ws / "sim/run.sh"
    if run_sh.exists():
        run_sh.write_text(run_sh.read_text().replace("timeout 200 ", "timeout --foreground 200 ")
                          .replace('.elf" 2>&1 || true)', '.elf" </dev/null 2>&1 || true)'))
    model = model or AGY_MODEL
    cmd = ["docker", "run", "--rm", "--name", name,
           "-v", f"{ws}:/work",
           "-v", f"{hooks}:/work/.agents:ro",
           "-v", f"{RISCV_GCC}:/opt/riscv:ro",
           "-v", f"{SPIKE_LIB}:/opt/spike-lib:ro",
           "-v", f"{AGY_BIN}:/opt/agy/agy:ro",
           "-v", f"{home}:/agy-home",
           "-e", "HOME=/agy-home", "-w", "/work",
           "-e", "LD_LIBRARY_PATH=/opt/spike-lib",
           "-e", "PATH=/opt/agy:/opt/riscv/bin:/usr/local/bin:/usr/bin:/bin",
           IMAGE, "agy", "-p", "Read TASK.md and complete the task.",
           "--output-format", "stream-json", "--dangerously-skip-permissions", "--model", model]
    t0 = time.time()
    try:
        with open(ep / "transcript.jsonl", "w") as log:
            try:
                p = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                   timeout=timeout_s)
                status = "exited" if p.returncode == 0 else f"exit {p.returncode}"
            except subprocess.TimeoutExpired:
                subprocess.run(["docker", "kill", name], capture_output=True)
                status = "wall timeout"
    finally:
        shutil.rmtree(home, ignore_errors=True)
    shutil.rmtree(ws / ".agents", ignore_errors=True)
    return {"agent_status": status, "model": model, "effort": model.rsplit("-", 1)[-1],
            "agy_account": AGY_TOKEN.parents[2].name,  # login home dir: agy-home (main) or agy-home2 (free tier)
            **summarize_agy(ep / "transcript.jsonl"), "duration_s": round(time.time() - t0, 3)}


def summarize_agy(path: pathlib.Path) -> dict:
    # num_turns counts finished tool steps; web_denied counts calls the no-web hook blocked.
    info = {"num_turns": 0, "cost_usd": None, "leak_hits": [], "usage": {}, "web_denied": 0, "agy_status": None}
    for line in path.read_text().splitlines():
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        su = ev.get("step_update") or {}
        if su.get("step_type") == "tool" and su.get("state") in ("DONE", "ERROR"):
            info["num_turns"] += 1
            tool = su.get("tool_info") or {}
            if "pre-tool hook" in json.dumps(tool.get("error") or ""):
                info["web_denied"] += 1
            text = json.dumps(tool.get("parameters"))
            for m in LEAK_RE.finditer(text):
                info["leak_hits"].append(text[max(0, m.start() - 60): m.end() + 60])
        if ev.get("event") == "result":
            info["agy_status"] = ev["result"].get("status")
            info["usage"] = ev["result"].get("usage") or {}
    return info


def summarize_codex(path: pathlib.Path) -> dict:
    # num_turns counts tool calls (commands, file edits), the closest analogue of Claude Code turns.
    info = {"num_turns": 0, "cost_usd": None, "duration_s": None, "leak_hits": [], "usage": {}}
    for line in path.read_text().splitlines():
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        item = ev.get("item") or {}
        if ev.get("type") == "item.completed" and item.get("type") not in (None, "agent_message", "reasoning"):
            info["num_turns"] += 1
            text = json.dumps(item)
            for m in LEAK_RE.finditer(text):
                info["leak_hits"].append(text[max(0, m.start() - 60): m.end() + 60])
        if ev.get("type") == "turn.completed":
            for k, v in (ev.get("usage") or {}).items():
                if isinstance(v, int):
                    info["usage"][k] = info["usage"].get(k, 0) + v
    return info


def summarize_transcript(path: pathlib.Path) -> dict:
    info = {"model": None, "num_turns": None, "cost_usd": None, "duration_s": None, "leak_hits": []}
    for line in path.read_text().splitlines():
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if ev.get("type") == "system" and ev.get("subtype") == "init":
            info["model"] = ev.get("model")
        if ev.get("type") == "result":
            info["num_turns"] = ev.get("num_turns")
            info["cost_usd"] = ev.get("total_cost_usd")
            info["duration_s"] = (ev.get("duration_ms") or 0) / 1000
        if ev.get("type") == "assistant":
            for block in ev.get("message", {}).get("content", []):
                if block.get("type") == "tool_use":
                    text = json.dumps(block.get("input"))
                    for m in LEAK_RE.finditer(text):
                        info["leak_hits"].append(text[max(0, m.start() - 60): m.end() + 60])
    return info


def grade_workspace(case: pathlib.Path, ws: pathlib.Path, ep: pathlib.Path) -> dict:
    src = ws / "repro.S"
    if not src.exists():
        return {"valid": False, "error": "no repro.S"}
    if src != ep / "repro.S":
        shutil.copy(src, ep / "repro.S")
    # Both `#include "test.h"` and `#include "harness/test.h"` must resolve to the pristine
    # harness, never to the workspace copy the model could have edited.
    link = ep / "harness"
    if link.is_symlink() or link.exists():
        link.unlink()
    link.symlink_to(ROOT / "harness/cva6")
    # Build in the episode dir (the Makefile writes build/ under its cwd) so parallel
    # episodes do not share an output path.
    build = subprocess.run(["make", "-s", "-f", str(ROOT / "harness/cva6/Makefile"), f"TEST={ep / 'repro.S'}",
                            f"CC={RISCV_GCC}/bin/riscv-none-elf-gcc"], capture_output=True, text=True, cwd=ep)
    elf = ep / "build/repro.elf"
    if build.returncode != 0:
        return {"valid": False, "error": "build failed", "log": build.stderr[-2000:]}
    shutil.move(elf, ep / "repro.elf")
    return grade.grade(case, ep / "repro.elf")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("case", type=pathlib.Path)
    ap.add_argument("--condition", choices=["sim", "nosim"], required=True)
    ap.add_argument("--run-id", required=True)
    ap.add_argument("--backend", choices=["claude", "codex", "gemini", *LOCAL_BACKENDS], default="claude")
    ap.add_argument("--model")
    ap.add_argument("--tier", choices=["full", "vague", "loc"], default="full",
                    help="report detail: symptom (full), subsystem only (vague), or file only (loc)")
    ap.add_argument("--max-turns", type=int, default=60)
    ap.add_argument("--timeout", type=int, default=2400, help="wall-clock seconds for the agent")
    ap.add_argument("--skip-done", action="store_true", help="keep an existing graded episode")
    ap.add_argument("--regrade", action="store_true", help="re-grade the saved repro.S; no agent run")
    a = ap.parse_args()
    case = a.case.resolve()
    ep = ROOT / "eval/runs" / a.run_id / f"{anon_id(case)}-{a.condition}"
    if a.regrade:
        result = json.loads((ep / "result.json").read_text())
        result["grade"] = grade_workspace(case, ep, ep)
        (ep / "result.json").write_text(json.dumps(result, indent=2))
        print(f"{case.name} [{a.condition}] regraded valid={result['grade'].get('valid')}")
        return
    if a.skip_done and (ep / "result.json").exists():
        print(f"{case.name} [{a.condition}] already done")
        return
    if ep.exists():
        shutil.rmtree(ep)
    ep.mkdir(parents=True)
    ws = build_workspace(case, ep, a.condition, a.tier)
    result = {"case": case.name, "anon_id": anon_id(case), "condition": a.condition, "run_id": a.run_id,
              "backend": a.backend, "tier": a.tier}
    result.update(run_agent(ws, ep, a.backend, a.model, a.max_turns, a.timeout))
    result["grade"] = grade_workspace(case, ws, ep)
    shutil.rmtree(ws / "core")  # large and identical to the build tree
    (ep / "result.json").write_text(json.dumps(result, indent=2))
    g = result["grade"]
    print(f"{case.name} [{a.condition}] valid={g.get('valid')} "
          f"fixed={g.get('fixed', {}).get('outcome')} buggy={g.get('buggy', {}).get('outcome')} "
          f"turns={result['num_turns']} leaks={len(result['leak_hits'])} agent={result['agent_status']}")


if __name__ == "__main__":
    main()
