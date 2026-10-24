# rtl-bug-repro-bench

Can a coding agent turn a bug report into a failing test for real processor RTL? This
benchmark gives an agent (headless Claude Code, sandboxed in Docker) the RTL of a CVA6 RISC-V
core with one real upstream bug put back in, a bare-metal test harness, and a written report.
The agent must write `repro.S`. It scores only if the program **passes on the fixed core and
does not pass on the buggy core**.

## Headline results

Bugs reproduced, full bug report, 14 cases (all numbers: [`results/SUMMARY.md`](results/SUMMARY.md)).

| Model | With simulator | Without simulator |
| --- | --- | --- |
| Claude Opus 5.5 (3 samples) | 39/42 (93%) | 41/42 (98%) |
| Claude Sonnet 5.5 (3 samples) | 39/42 (93%) | 37/42 (88%) |
| GLM 5.3 Flash (1 sample) | 10/14 (71%) | 10/14 (71%) |
| Qwen3.8-27B (3 samples, 60-turn cap) | 19/42 (45%) | 23/42 (55%) |
| Qwen3.8-27B (1 sample, 120-turn cap) | 11/14 (79%) | - |
| Granite 4.2 8B (1 sample) | 1/14 (7%) | 0/14 (0%) |

With less detail in the report (simulator, 3 samples), Opus 5.5 falls to 25/42 (60%) given one
sentence naming the subsystem and to 16/42 (38%) given only the patched file names; Sonnet 5.5
falls to 20/42 (48%) and 12/42 (29%).

## Layout

| Path | What |
| --- | --- |
| `cases/cva6-<sha>/` | One case per upstream fix: `bug.patch` (reverts the fix on CVA6 HEAD), `target` (config), `report.md` / `report_vague.md` / `report_loc.md` (the three report tiers), `repro.S` + `grade_reference.json` (our reference reproducer and its two-sided grade) |
| `harness/cva6/` | Bare-metal harness given to the agent (`test.h`, `hyp.h`, `crt.S`, `link.ld`, `Makefile`) and the two benchmark configs we added (`configs/`) |
| `scripts/` | `mine_fixes.py` (candidate mining), `cva6_build.sh` (Verilator builds), `grade.py` (two-sided grading), `export_results.py` (this repo's `results/`) |
| `eval/` | `run_episode.py` (one episode: workspace, sandbox, agent, grading), `run_batch.sh`, `tier_queue.sh` and the other queue scripts, `docker/Dockerfile`, local-model serving scripts |
| `data/` | Mined candidate lists, case triage (`triage_cva6.md`), the Sdtrig load-hang investigation and our fix used as the 49b5fa9e2f reference core |
| `results/` | `episodes.csv` (one row per episode), `SUMMARY.md`, and per episode `runs/<run>/<anon-id>-<cond>/{result.json,repro.S}` |
| `NOTES.md` | Lab notebook, in date order |

Agent transcripts (529 episodes, 1.5 GB uncompressed) are attached to the GitHub release as
`transcripts.tar.zst`, with the same `<run>/<anon-id>-<cond>/` layout.

## Reproducing

Requirements: Linux, Docker, [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)
2023-03-05 (Verilator 5.008; newer Verilator rejects CVA6 HEAD), the xPack `riscv-none-elf-gcc`
15.2.0 toolchain, and `device-tree-compiler`. `env.sh` expects both toolchains under `~/tools`.

1. Clone CVA6 into `cores/cva6` at commit `81245a47fad8fe1a5d562d953ef2662e099def76` with
   submodules, and build Spike/libfesvr with `verif/regress/install-spike.sh` (see `NOTES.md`,
   Day 2, for the flags that build needs).
2. Build the simulators: `TARGET=<config> scripts/cva6_build.sh fixed` for each config, and
   `scripts/cva6_build.sh cases/cva6-<sha>` for each case.
3. Check a case: `python3 scripts/grade.py cases/cva6-<sha> <elf>` with the reference
   `repro.S` built by `make -C harness/cva6 TEST=...`.
4. Build the sandbox image from `eval/docker/Dockerfile` with a Claude Code 2.1.302 binary
   copied in as `eval/docker/claude`, tagged `rtlbench-agent:2.1.302`.
5. Run episodes: `eval/run_batch.sh <run-id> <sim|nosim> <parallel> --model opus --tier full`.
   Claude backends read an OAuth token from `~/.config/rtlbench/token`; local backends
   (`--backend glm|qwen|granite`) expect an Anthropic-compatible server on the ports in
   `run_episode.py`.

Some serving scripts (`eval/serve_granite.sh`, `eval/recover_qwen.sh`) contain paths from the
original machine; adjust them for yours.

## Notes on the data

- **Void episodes** (cut off by the subscription usage limit or a provider API error) were
  deleted and rerun; any left are marked `void=1` in `episodes.csv` and excluded from the tables.
- **Excluded runs:** `qwen1` (Qwen's chat template rejected Claude Code's default reasoning
  effort, so every request failed), `opus1-retry` (a rerun of one episode a safety classifier
  stopped; the original stays as the sample), and the harness bring-up pilots.
- **`sandbox_flags`** counts tool calls that mention a URL, git, curl, wget, the upstream org or
  the case directory. They mark attempts; the sandbox has no download tools and no access to
  the case files.
- **Contamination:** 11 of the 14 fixes landed upstream in August-September 2026. 0e04a86b13 and
  aef009c4b3 (March 2026) and 18b9875e9d (June 2026) may be in the models' training data.
- **Withheld reproducers:** four episodes (`opus-loc-s1`, `opus-loc-s2`, `opus-loc-s3`,
  `sonnet-vague-s3`) found a distinct, unfixed deviation that has been reported privately
  upstream. Their `repro.S` is replaced by a notice and their transcripts are left out of
  `transcripts.tar.zst`; `result.json` and the `episodes.csv` rows are kept.
- **Opus 4.8 fallback:** in 8 Opus episodes a refusal classifier switched the session to Opus
  4.8; they are still labelled Opus 5.5. See `analysis/cyber_downgrades.md`.
- `cost_usd` is Claude Code's API-price estimate. For local models it is meaningless.

## License

CVA6 is licensed under the Solderpad Hardware License v0.51; the `bug.patch` files and
`data/sdtrig_loadaddr_fix_v2.patch` modify CVA6 sources.
