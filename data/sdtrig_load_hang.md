# CVA6: a load that hits an mcontrol6 load-address trigger hangs the core

Status: reproduced on upstream HEAD `81245a47f` (2026-09-15, openhwfoundation/cva6 master).
Not reported as far as a GitHub issue search found (the search API rate-limited one query).
Not reported upstream by us. A candidate fix (local only) is below.

## Configuration

`cv64a6_imafdc_sv39` with Sdtrig, SdtrigMcontrol6, SdtrigMcontrol6LoadAddr/ExecAddr/Store
enabled (`harness/cva6/configs/cv64a6_imafdc_sv39_sdtrig_config_pkg.sv`). No shipped config
enables Sdtrig; the upstream unit test `verif/tb/unit/trigger_loadaddr_test.sv` enables the
same LoadAddr options but exercises `trigger_module` alone, not the load unit.

## Symptom (`data/sdtrig_debug/`)

| variant | result on the fixed core |
|---|---|
| load hits NAPOT trigger (`ld`, `lw`) | hang |
| load hits exact-match trigger | hang |
| load misses the trigger | correct (ecall, cause 8) |
| store hits NAPOT trigger | correct (breakpoint, cause 3) |

## Mechanism (VCD of variant B, times in half-cycles)

- t=833: `fire_req_LA` valid (action 3). Same cycle, the load unit accepts the load
  (`lsu_ctrl_i.trans_id = 2`), pops it (`pop_ld_o = 1`) and issues the D-cache request.
- t=835: the registered `sdtrig_load_cancel` arrives; the load unit kills the request.
  Last change of `commit_ack_o`; nothing commits afterwards.
- t=837: LOAD_WB writes back a breakpoint exception with `trans_id = 0`, `tval = 0`,
  taken from the now-empty `lsu_ctrl_i` (load_unit.sv cancel path:
  `trans_id_o = lsu_ctrl_i.trans_id`, `tval = lsu_ctrl_i.vaddr`).
- No writeback for trans_id 2 ever arrives, so commit waits on that scoreboard entry forever.

Store-address triggers do not hang, because they stall the store unit
(`sdtrig_store_stall_o`) instead of cancelling after the operation was popped. They have a
different problem with back-to-back stores (last section).

## Tools

`scripts/vcd_pick.py` (VCD signal dump); trace build:
`TARGET=cv64a6_imafdc_sv39_sdtrig NAME_SUFFIX=-trace MAKE_EXTRA="TRACE_FAST=1" scripts/cva6_build.sh fixed`.
`+max-cycles` does not stop a traced run: cap the dump with `-v - | head -c N`.

## A second symptom: the cancel lands on the wrong load

With other loads in flight, the registered cancel can hit an older queued load instead of the
matching one. In `Q_stress.S` (64 iterations: `ld`, `sd`, `ld` from the same address, then the
matching `ld`), a patch that only stalled the load unit for one cycle gave 127 traps, a wrong
checksum, and an unexpected entry into Debug Mode. The match is computed on the load *entering*
the LSU, but the cancel acts on whatever load the load unit holds a cycle later.

## Candidate fix: `data/sdtrig_loadaddr_fix_v2.patch` (45 lines, 6 files)

Tag the load itself instead of cancelling a cycle later:
- `trigger_module`: on a load-address hit, drive a new combinational `sdtrig_load_addr_hit_o`
  (1 = breakpoint, 2 = debug request) instead of the registered cancel/action.
- `csr_regfile`, `cva6`, `ex_stage`, `load_store_unit`: carry it into a new
  `lsu_ctrl_t.sdtrig_load_addr_hit` field, set only for loads, as the request enters the LSU.
- `load_unit`: a tagged load is never sent to memory. In IDLE, when no response competes for
  `valid_o`, it is popped and written back with the exception (its own trans_id; tval = vaddr).

Build: `TARGET=<cfg> NAME_SUFFIX=-lafix2 EXTRA_PATCH=$PWD/data/sdtrig_loadaddr_fix_v2.patch scripts/cva6_build.sh fixed`.

| test (`data/sdtrig_debug/`) | original | v2 |
|---|---|---|
| A/B/E: load hits (NAPOT, exact, `ld`, `lw`) | hang | breakpoint |
| C/F/G: load misses, trigger disarmed | ecall | ecall |
| D: store hit; X: NAPOT execute trigger | breakpoint | breakpoint |
| P_precise: mepc = load, mtval = address, rd untouched, execution resumes | hang | pass |
| Q_stress / R_arm1: 64 hits among loads/stores | hang | 64 hits, checksum 2528 |

Regression: all 12 reference reproducers on v2-patched fixed cores (default, hypervisor and
Sdtrig configs) still pass; smoke pass/fail as expected. Not rebuilt: hpdcache and M+U configs.

Upstream unit test `verif/tb/unit/trigger_loadaddr_test.sv` asserts the old cancel pulse, so
it fails on v2 by design (line 138). An updated copy (`unit/v2/trigger_loadaddr_test.sv`)
checks the new tag and keeps the hit0 and #3491 checks; it passes.

Limits: one config family; directed tests only, no random or formal checking; the debug-request
action (2) is not exercised because no debugger is attached.

## Separate finding, not root-caused: store-address triggers miss back-to-back hits

`S_store_stress.S` (same loop, matching `sd`): 1 of 64 matching stores traps; the other 63
complete silently. Same on the original and v2 cores (v2 does not touch the store path).
