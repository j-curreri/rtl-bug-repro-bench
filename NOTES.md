# rtl-bug-repro-bench: working notes

## Day 1 (2026-10-17)

- Toolchains in `~/tools` (no sudo): OSS CAD Suite 2026-10-17 (Verilator 5.053, Yosys 0.70,
  SymbiYosys, Icarus) and xPack riscv-none-elf-gcc 15.2.0. `source env.sh` to use them.
- Cores cloned under `cores/`: ibex, cva6, picorv32, VexRiscv (VexRiscv is SpinalHDL/Scala,
  deprioritized).
- PicoRV32: `make test TOOLCHAIN_PREFIX=riscv-none-elf-` passes in Icarus.
- CVA6: submodules initialized; `make verilate` needs `RISCV` set and libfesvr from Spike
  (see `verif/regress/install-spike.sh`). Not built yet.
- Candidate fix commits (`scripts/mine_fixes.py`, 1-2 RTL files, <=40 changed lines):

  | core     | total | since 2025 | since 2026-03 |
  |----------|------:|-----------:|--------------:|
  | cva6     |   151 |         61 |            31 |
  | ibex     |    79 |          7 |             3 |
  | picorv32 |    33 |          0 |             0 |

  Raw lists: `data/cand_*.jsonl`. These are keyword matches and still need manual triage.

## Day 2 (2026-10-17)

- Spike/libfesvr built via `verif/regress/install-spike.sh` with `CMAKE_POLICY_VERSION_MINIMUM=3.5`,
  `CXXFLAGS="-O2 -include cstdint"`, and `CPATH` pointing at Verilator's include dirs.
  Needs `device-tree-compiler` (installed via apt).
- Verilator 5.053 (OSS CAD nightly) rejects streaming concatenations in vendored
  `axi_riscv_amos.sv` after a 38-minute elaboration. Using OSS CAD Suite 2023-03-15
  (Verilator 5.008-44) with CVA6's `verilator-v5.patch` hand-applied to `verilated_types.h`.
- Buggy variants = HEAD + `cases/<case>/bug.patch` (reverse of the fix; hand-written when the
  reverse does not apply). One fixed build serves every case.
- `scripts/cva6_build.sh`, `scripts/grade.py`; triage in `data/triage_cva6.md`.

- CVA6 builds with OSS CAD Suite 2023-03-05 (Verilator 5.008-1); 2023-03-15 (5.008-44) rejects
  static variables in loops in `cva6_rvfi.sv`. A build takes about 20 s with 5.008-1, versus 38+ min
  (then failing) with 5.053-devel.
  One simulator run takes about 11 s wall time, mostly startup.
- Reference reproducers validated (pass on fixed, fail on buggy): d2fdf99a38, 194d39face,
  6fe7b95910, 0e04a86b13. 49b5fa9e2f is blocked: Sdtrig is disabled in every shipped config.

## Day 3 (2026-10-17)

- Builds are per config: `builds/<config>/cva6-{fixed,<case>}`; a case's config is in `cases/<case>/target`.
- Added `harness/cva6/hyp.h` (1 GiB-leaf G-stage/VS-stage tables, ENTER_VS) and `rv64gc_..._h`.
- 13 validated cases: 4 default, 7 hypervisor, 1 hpdcache (Zicbom), 1 custom Sdtrig config.
- Hand-written patches where the plain revert breaks later code: 0e04a86b13, fc5fffba6f,
  2d2d0c11b7 (later commit reuses `hlvx_inst_q`).
- grade.py now runs each simulation in a temp dir and reports cycle-limit runs as timeouts.

## Evaluation (2026-10-17)

- `eval/run_episode.py`: one episode = headless Claude Code (2.1.302) in Docker image
  `rtlbench-agent:2.1.302` (no git/curl/wget/python), workspace-only mount, anonymized case id,
  buggy `core/` RTL, harness, our report. `sim` adds `sim/run.sh` (buggy core only).
  Grading on the host with the pristine harness (`ep/harness` symlink). `--regrade` re-scores.
- Backends: `claude` (subscription token from `~/.config/rtlbench/token`), `glm` (FreeToken
  :1919, 131k KV), `qwen` (SGLang :8096, 262k). Local backends get no Anthropic credentials.
- Atria-Dawn remote API: key valid, but quota exhausted (HTTP 429) as of 2026-10-17.
- Claude Sonnet 5.5, 1 sample/cell: sim 12/14, nosim 11/14. 18b9875e9d and fc5fffba6f fail in
  both conditions (tests never pass on the fixed core); 9a0e01e383 fails only without sim.
- `eval/overnight.sh` (detached): GLM sim+nosim serially, then swaps the RTX PRO 6000 to SGLang
  Qwen3.8-27B for sim+nosim at 4-way parallelism. Log: `eval/runs/overnight.log`.
- 2026-10-18 01:56: reordered. overnight.sh stopped after starting the GLM sim batch;
  `eval/overnight2.sh` waits for it, then runs Qwen sim+nosim, then GLM nosim.

## Plan

- CVA6 is the primary core: many small, recent (post-training-cutoff) functional fixes.
- PicoRV32 is the smoke-test core: simple, fast, and its old classic bugs (jalr, C.ADDI,
  RV32E shifts, fence decode) are fine for building the harness even though models may
  have seen them.

## Results 2026-10-18 evening

- Opus 5.5 sim: 12/14 (cost 3.13 USD API-equivalent). Misses: 9a0e01e383 (safety classifier stopped
  the episode after 4 turns) and 49b5fa9e2f (its test arms load+store triggers, so it hits the
  Sdtrig load-hang bug on the fixed core; it passes on HEAD + sdtrig_loadaddr_fix_v2 and fails on
  the buggy core). Opus also solved 18b9875e9d and fc5fffba6f, which Sonnet missed.
- GLM 5.3 Flash sim: 10/14 (0e04a86b13, 194d39face, 6fe7b95910, 99a0807757 invalid).
- Qwen1 sim+nosim: void. Every request returned HTTP 500: the Qwen chat template rejects
  Claude Code's reasoning effort "high" (accepts xhigh/medium/low). Needs a rerun.
- run_episode.py passes `--effort xhigh` for the qwen backend. `eval/after_glm.sh` (detached) waits
  for overnight2.sh, starts SGLang, runs a one-turn Claude Code smoke request, then qwen2 sim+nosim.
- Opus nosim batch and a retry of 9a0e01e383 sim (run-id opus1-retry) started 2026-10-18 evening.
- Opus 5.5 nosim: 13/14 (4.89 USD); misses only 49b5fa9e2f (fixed core times out again). Opus retry
  of 9a0e01e383 sim: valid (7 turns). The original classifier-stopped episode stays sample 1.

## Report tiers and samples (2026-10-18)

- Each case has `report.md` (full: symptom), `report_vague.md` (subsystem, one sentence) and
  `report_loc.md` (only the patched files). `run_episode.py --tier {full,vague,loc}`.
- `eval/tier_queue.sh` (detached, log `eval/runs/tier_queue.log`), run ids `<model>-<tier>-s<k>`:
  vague/loc sim s1 for Opus and Sonnet; full sim+nosim s2,s3; vague/loc sim s2,s3. Stops when a
  batch has 3+ void episodes (usage limit).
- Loc tier caveat: a test exposing a *different* real bug in the same file fails on both cores
  and scores zero; only the patched bug counts.
- 49b5fa9e2f reference core is now HEAD + sdtrig_loadaddr_fix_v2 (cases/<case>/reference, grade.py); opus1 regraded. tier_queue stopped 20:27 on the session usage limit after opus-vague-s1 (5/14, 5 void).
- 2026-10-19 00:32: tier_queue.sh now deletes void episodes (usage-limit or API-error transcripts)
  before each batch so --skip-done reruns them, and counts valid from result.json. Restarted;
  it reruns the 5 void opus-vague-s1 episodes first, then continues the queue.
- GLM 5.3 Flash nosim: 10/14 (done 2026-10-19 11:14).
- Qwen2: after_glm.sh smoke failed at 11:19 (unrecognized_model/API error right after SGLang came
  up). eval/recover_qwen.sh (written by Codex, 12:40) waits on /health, re-runs the smoke, then runs
  qwen2 sim+nosim; running.
- tier_queue restarted 2026-10-19 14:13 (opus-loc-s1 had 5/14 valid, 4 void at the 09:44 limit).
- 2026-10-19 19:11: Qwen2 sim 6/14 (done); sonnet-vague-s1 6/14; sonnet-loc-s1 stopped (8 void) at 15:09; tier_queue restarted.
- Qwen3.8-27B (qwen2): sim 6/14, nosim 9/14. In sim, 8 of 14 episodes hit the 60-turn cap
  (iterating on the simulator), so the turn cap, not the simulator, likely explains sim < nosim.
  SGLang stopped 2026-10-19 19:40; GPU free.
- eval/qwen_samples.sh (started 2026-10-19 ~19:50, log eval/runs/qwen_samples.log): Qwen full tier
  s2,s3 sim+nosim (run ids qwen-full-s2/s3; qwen2 is s1), then qwen-turns120 sim (120-turn cap)
  to test the turn-cap explanation. Stops SGLang at the end.
- 2026-10-20 00:11: opus-full-s2 sim 14/14, nosim 13/14; sonnet-full-s2 sim 13/14 (1 void); sonnet-loc-s1 4/14; qwen-full-s2 sim 6/14. tier_queue restarted (sonnet-full-s2 nosim was all void).
- Granite 4.2 8B (Codex: eval/GRANITE.md, serve_granite.sh, run_granite.sh, backend `granite`, 131k).
  eval/after_qwen.sh (detached, waits on qwen_samples.sh) serves it on the RTX PRO 6000, runs
  run_granite.sh granite1 (tool smoke, sim+nosim), then stops the server. Log: overnight.log.
- 2026-10-20 05:11: full s3: opus sim 12 nosim 14, sonnet sim 13 nosim 13; qwen-full-s2 nosim 7/14. tier_queue restarted at opus-vague-s2 (13 void at 01:01).
- 2026-10-20 10:11: opus-vague-s2 10/14; qwen-full-s3 nosim 7/14; qwen-turns120 sim started 09:56. tier_queue restarted at opus-loc-s2 (all void at 05:42).
- Qwen full tier, 3 samples: sim 6,6,7 (19/42), nosim 9,7,7 (23/42). qwen-turns120 sim: 11/14,
  so the 60-turn cap explains sim < nosim. Granite granite1 started 2026-10-20 14:40.
- tier_queue restarted 15:11 (opus-loc-s2 had 5 valid, 8 void).
- 2026-10-20 17:10: Granite restarted via eval/restart_granite.sh
  (detached; eval/runs/granite1-restart.log). Health and tool smoke passed; granite1 sim
  resumed with four concurrent episodes, then nosim. Three completed results preserved;
  four interrupted episode directories and prior server/smoke logs archived under
  eval/runs/granite1-interrupted-20261020-170908/. Server stops when the run exits.

- 2026-10-20 19:52: Granite restarted from `/mnt/k3/rtl-bug-repro-bench`; restart_granite.sh
  and run_granite.sh now derive the repo path from their own location instead of Downloads.
  Health and tool smoke passed; granite1 sim resumed at four-way concurrency, preserving
  three completed results, then nosim. Interrupted episodes and server/smoke logs archived
  under eval/runs/granite1-interrupted-20261020-195201/. Restart PID 280048;
  log eval/runs/granite1-restart.log. Server stops when evaluation exits.

- 2026-10-20 20:56: Granite restarted from `/mnt/k3` (restart_granite.sh). Interrupted episodes and the previous
  server and smoke logs archived under eval/runs/granite1-interrupted-20261020-205609/.

- 2026-10-20 23:17: Granite restarted on the RTX PRO 6000. Interrupted episodes and server/smoke logs archived under eval/runs/granite1-interrupted-20261020-231654/.
- 2026-10-21 00:28: Granite restarted on the RTX PRO 6000. Interrupted episodes archived
  under eval/runs/granite1-interrupted-20261021-002727/. tier_queue.sh now takes `MODELS` (default "opus sonnet");
  restarted as `MODELS=opus eval/tier_queue.sh`. Remaining Opus work: 1 void opus-loc-s2 episode, then opus-vague-s3 and opus-loc-s3.
- 2026-10-21 01:10: opus-loc-s2 7/14 and opus-vague-s3 11/14 (0 void each). opus-loc-s3 went all void at 00:58 (session limit,
  reset 06:10 UTC); MODELS=opus tier_queue restarted 01:10 and is rerunning opus-loc-s3 (the last Opus batch).
- 2026-10-21 04:14: granite1 finished (sim + nosim). 01:36: opus-loc-s3 4/14 with 2 void; queue rerun at 06:10 for those 2.
- 2026-10-21 06:13: Opus queue complete (0 void anywhere). opus-loc-s3 4/14. Opus totals (bugs reproduced): full sim 13,14,12 (39/42),
  full nosim 14,13,14 (41/42), vague sim 8,10,11 (29/42), loc sim 5,7,4 (16/42). (opus1 counted from current result.json, after regrade.)
- 2026-10-21 09:46: Sonnet queue started (`MODELS=sonnet eval/tier_queue.sh`): sonnet-vague-s2 (rerun of 14 void), loc-s2, vague-s3, loc-s3.
- 2026-10-21 10:07: eval/qwen_turns120_nosim.sh (detached): SGLang Qwen3.8-27B on the PRO 6000, qwen-turns120 nosim at a
  120-turn cap (counterpart of the 11/14 sim run), then stops SGLang. Log eval/runs/qwen_samples.log.
- 2026-10-21: eval/qwen_tiers120.sh queued (detached): after qwen_turns120_nosim.sh exits, restarts SGLang and runs
  Qwen vague and loc tiers, sim, 120-turn cap (run ids qwen120-vague-s1, qwen120-loc-s1), then stops SGLang.
- 2026-10-21 11:47: Sonnet queue complete. vague sim 6,4,6 (16/42), loc sim 4,3,1 (8/42). sonnet-vague-s3 hit the session
  limit at 10:23 (10 void) and was rerun after the 16:10 UTC reset. Paper and release results updated.
- 2026-10-21 13:31: qwen-turns120 nosim 8/14 (max 68 turns, cap never binds) vs sim 11/14: with enough turns the simulator
  helps Qwen. qwen_tiers120.sh now starting (vague, then loc).
- 2026-10-21 late: classified the 40 Opus/Sonnet loc-tier tests that fail on both cores
  (`eval/analysis/loc_failfail.md`): 24 hit real deviations still in the fixed core (8 distinct, D1-D8), 9 misread the spec,
  7 are broken. Found that sim runs since the move to /mnt/k3 have a broken `sim/run.sh` (RUNPATH points at
  ~/Downloads, which the container doesn't mount; libfesvr.so not found). Not fixed yet, pending decision.
- 2026-10-22 00:03: fixed in-container sim: `run_episode.py` now mounts the Spike lib at /opt/spike-lib and sets
  LD_LIBRARY_PATH (the simulators' RUNPATH still names ~/Downloads). Smoke-tested in the image. Broken-sim runs moved to
  `eval/runs/_brokensim-20261022/`: opus-vague-s3, opus-loc-s3, sonnet-{vague,loc}-s{2,3}, qwen120-{vague,loc}-s1 and
  opus-loc-s2/case-b1ec9b. Relaunched: `eval/qwen_tiers120_rerun.sh` (reuses SGLang :8096) and
  `MODELS="opus sonnet" eval/tier_queue.sh` (skip-done refills the moved runs). granite1 has 6 broken-sim
  episodes still in place (not rerun).
- 2026-10-22: found that 8 Opus episodes were silently served by Opus 4.8, not the requested 5.5. An upstream
  refusal classifier (category "cyber") fired and the transcript shows a session-scoped
  fallback (original_model claude-opus-5-5 -> fallback_model claude-opus-4-8); every turn after the stop runs on
  4.8. 6 of the 8 are the PMP case cva6-6fe7b95910 (U-mode defeating memory protection); 7 of 8 scored valid.
  result.json records the REQUESTED model, so episodes.csv/export count these as Opus 5.5 -> some reported Opus
  5.5 full/vague results were actually Opus 4.8. 3 more episodes had a response blocked with no downgrade and
  ended early (opus-full-s3/case-2696e8-sim, opus-full-s3/case-a6eafa-sim, opus1/case-a6eafa-sim). Details +
  per-episode table: eval/analysis/cyber_downgrades.md and cyber_downgrades.csv. Regenerate the CSV with:
    cd eval/runs; python3 -I <<'PY'  # scans */case-*/transcript.jsonl for model-per-turn + refusal events
    import json,glob,os,csv,sys
    w=csv.writer(sys.stdout); w.writerow(['run','anon_cond','case','label_model','served_opus48_turns','total_turns','classifier_stops','refusal_category','valid'])
    out=[]
    for f in sorted(glob.glob('*/case-*/result.json')):
        ep=os.path.dirname(f); t=ep+'/transcript.jsonl'
        if not os.path.exists(t): continue
        d=json.load(open(f)); mdls=[]; stops=0; cat=''
        for line in open(t,errors='ignore'):
            try:o=json.loads(line)
            except:continue
            m=o.get('message') or {}
            if isinstance(m,dict) and m.get('model'): mdls.append(m['model'])
            s=json.dumps(o)
            if 'stopped by a safety classifier' in s: stops+=1
            if '"api_refusal_category"' in s:
                try: cat=json.loads(line).get('api_refusal_category') or cat
                except: pass
        n48=mdls.count('claude-opus-4-8')
        if n48 or stops: out.append([ep.split('/')[0],ep.split('/')[1],d['case'],d.get('model'),n48,len(mdls),stops,cat,(d.get('grade') or {}).get('valid')])
    out.sort()
    [w.writerow(r) for r in out]
    PY
- 2026-10-22 10:52 CDT: tier_queue had stopped 02:29 (opus-vague-s3 1/14 valid, 12 void, session limit reset 11:30 UTC).
  claude_queue_guard.sh exited at 06:31 thinking the queue was done (it treats STOP as done), so nothing
  restarted it. Restarted by hand: `MODELS="opus sonnet" eval/tier_queue.sh`. Remaining: opus-vague-s3 (12 void
  reruns), opus-loc-s3, sonnet-vague-s3, sonnet-loc-s3. qwen120-loc-s1 rerun in progress (qwen120-vague-s1 rerun: 3/14).
- 2026-10-22 16:58 CDT: opus-vague-s3 done 7/14 (0 void). opus-loc-s3 went all void at 11:34 (session limit, reset 20:50 UTC);
  tier_queue restarted by hand 16:58 (MODELS="opus sonnet"). Left: opus-loc-s3, sonnet-vague-s3, sonnet-loc-s3.
- 2026-10-22: queued `glm-d6-s1..s10`, 10 GLM-5.3-Flash samples on one loc-tier case (details withheld pending a
  security advisory). Not a tier sample; excluded from the results tables.
- 2026-10-22 21:51 CDT: opus-loc-s3 stopped 17:28 (4 valid, 6 void; reset 02:50 UTC). tier_queue restarted by hand
  (MODELS="opus sonnet"); left: 6 opus-loc-s3 reruns, sonnet-vague-s3, sonnet-loc-s3.
- 2026-10-23 02:51 CDT: opus-loc-s3 complete 5/14 (0 void). sonnet-vague-s3 went all void 22:23 (session limit, reset
  07:50 UTC); tier_queue restarted by hand. Left: sonnet-vague-s3, sonnet-loc-s3.
- 2026-10-23 09:53 CDT: Claude queue done 04:26: sonnet-vague-s3 8/14, sonnet-loc-s3 5/14 with 1 void (cva6-cc81a7bb49,
  session limit; reset 12:50 UTC). MODELS=sonnet tier_queue restarted to rerun that one episode.
- 2026-10-23 ~11:00 CDT: Claude queue fully done (sonnet-loc-s3 void rerun scored; 5/14). Re-exported into the release repo
  (568 episodes, 532 scored; export_results.py now excludes glm-d6-* from tier tables). Sim-fixed totals: Opus vague 25/42,
  loc 16/42; Sonnet vague 20/42, loc 12/42; qwen120 vague 3/14, loc 3/14. Turn cap binds for Claude at vague/loc (Opus: 10 of 17
  vague misses at 61 turns). Paper doc updated (rev 49): tier numbers + chart, cap finding, Opus 4.8 fallback limitation,
  broken-sim note, sandbox flags (2 Sonnet git calls; 18 local, 5 scored). D6 episode (opus-loc-s1) was all Opus 5.5.
- 2026-10-24: glm-d6-s1..s10 finished (excluded run). Release repo re-synced: 573 episodes, 532 scored.
