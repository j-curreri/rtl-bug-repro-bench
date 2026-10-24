# Loc-tier tests that fail on both cores (Opus + Sonnet, 40 episodes)

Per-episode table: `loc_failfail.csv`. Probe variants: `loc-probes/` (`grade_variant.sh <case> <test.S>`).

Method: every one of the 40 stops at the same `FAIL(n)` on the fixed and buggy cores, so the
injected bug never changes the outcome. For each one I read `repro.S` and the agent's final message,
compared them with `bug.patch`, and ran the ELF on Spike (`cores/cva6/tools/spike`, ISA chosen to
match the config). Spike passing a test does not settle it: each candidate was also checked against
the spec and the RTL, and four were checked with edited variants on both cores.

| Category | Opus | Sonnet | Total |
| --- | --- | --- | --- |
| Real deviation in the fixed core (spec and Spike agree with the test) | 16 | 8 | 24 |
| Spec misread (expects behaviour the spec doesn't require) | 2 | 7 | 9 |
| Broken test (wrong config, register clobber, timing, unfinished) | 1 | 6 | 7 |

Only 1 of the 40 targeted the injected mechanism (2d2d0c11b7, sonnet-loc-s1). It fails on the fixed
core because the upstream fix is incomplete (D5). In 4 episodes the agent found the injected bug and
set it aside as an "upstream quirk" (9a0e01e383 opus s1/s2, d2fdf99a38 opus s1, fc5fffba6f opus s1).

## Deviations from the spec still present in the fixed core (CVA6 81245a47fa + case fix)

| Id | Deviation | Episodes |
| --- | --- | --- |
| D1 | pmpaddr reads bit 0 as 1 in NAPOT mode at G=1 (`csr_regfile.sv` ~L1000) | 9 |
| D2 | H configs: U-mode counter access gated by `~mcounteren & ~scounteren`; the spec needs `\|` (`csr_regfile.sv` L2575, L2593) | 6 |
| D3 | G-stage U bit not checked on the leaf that maps a VS page table (`cva6_ptw.sv`) | 4 |
| D4 | HLVX that hits the DTLB accepts a G-stage page with R=1, X=0 (`cva6_mmu.sv` L572) | 2 |
| D5 | HLV right after HLVX inherits execute-as-read (stale `hlvx_inst_q`): the 2d2d0c11b7 fix is incomplete | 1 |
| D6 | *(withheld pending a security advisory filed privately with the upstream maintainers)* | 1 |
| D7 | Vectored stvec keeps a BASE that is not 256-byte aligned, then ORs the cause into bits [7:2] (`csr_regfile.sv` L1427, L2713) | 1 (agent's test broken; my repaired variant confirms) |
| D8 | Store whose page walk hits a PMP denial reports a load access fault on H configs (`cva6_mmu.sv` L751) | 1 |

Mentioned by agents but not tested: menvcfg/senvcfg share one FIOM bit; the VU-mode branch of the counter check.

## Harness bug found along the way

The `Variane_testharness` binaries have RUNPATH `/home/bob/Downloads/rtl-bug-repro-bench/cores/cva6/tools/spike/lib`,
but `run_episode.py` mounts the Spike lib at `ROOT/...`. Since runs moved to `/mnt/k3` (2026-10-20 evening),
`sim/run.sh` fails in the container with `libfesvr.so: cannot open shared object file` unless the agent sets
`LD_LIBRARY_PATH` itself. Affected sim runs: opus-vague-s3 (13/14), opus-loc-s3, sonnet-vague-s2/s3,
sonnet-loc-s2/s3, qwen120-vague-s1 (14/14 each), granite1 (6/14), opus-loc-s2 (1/14), and qwen120-loc-s1 (running).
Grading on the host is unaffected.
