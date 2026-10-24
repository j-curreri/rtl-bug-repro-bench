# CVA6 candidate triage (fixes since 2026-03)

A bug is accepted only once we have written a reference reproducer that fails on the
parent commit and passes on the fix commit. Commit messages are detailed and often name
the faulty signal, so they must never be shown to the model; each case gets a
symptom-level report written by us.

## A. Default config (cv64a6_imafdc_sv39), deterministic, architecturally visible

All four have a reference reproducer that passes the two-sided check (`cases/*/grade_reference.json`).

| sha | area | observable symptom |
|---|---|---|
| d2fdf99a38 | csr_regfile | MRET/SRET to a less-privileged mode leaves mstatus.MPRV set |
| 194d39face | csr_regfile | mtval/stval not zeroed on interrupt traps (ZERO_TVAL=0 without SPIKE_TANDEM) |
| 6fe7b95910 | pmp_entry | PMP TOR boundary uses pmpaddr bit 0 although grain is 8 bytes |
| 0e04a86b13 | decoder, branch_unit | ebreak tval not the PC; ecall tval not zero (misaligned-jump part unreachable with RVC) |

## B. Default config, timing-dependent (include only if reproduced)

| sha | area | notes |
|---|---|---|
| 47b72e3193 | cva6_mmu | canonical-address check uses unregistered LSU signals |
| 378ed3bcfc | cva6_mmu | DTLB same-cycle PPN wrong for megapages |
| b30e7dba3e | load_unit | flushed load writes back if flush and dcache grant coincide |
| 3d540ac853 | cva6_mmu, lsu | PMP response metadata misaligned with request |
| ceb56a5c0e | axi_adapter | SC lock while waiting for AXI AW |

## C. Other configs (validated)

All have a reference reproducer that passes the two-sided check.

| sha | config | observable symptom |
|---|---|---|
| 81245a47fa | cv64a6_imafdch_sv39 | hgatp write with unsupported MODE is dropped entirely |
| fc5fffba6f | cv64a6_imafdch_sv39 | MRET with MPP=M, MPV=1 sets V=1 |
| 99a0807757 | cv64a6_imafdch_sv39 | bad non-leaf VS-stage PTE gives page fault instead of guest-page fault |
| 2d2d0c11b7 | cv64a6_imafdch_sv39 | HLV after HLVX on execute-only G-stage page succeeds |
| 9a0e01e383 | cv64a6_imafdch_sv39 | HLVX lets the VS-stage walk read an execute-only G-stage page |
| 18b9875e9d | cv64a6_imafdch_sv39 | G-stage-only fetch at GPA with bit 38 set page-faults |
| 2a12275c11 | cv64a6_imafdch_sv39 | illegal instruction in VS-mode sets mstatus.GVA |
| cc81a7bb49 | cv64a6_imafdc_sv39_hpdcache | menvcfg.CBIE keeps reserved encoding 2'b10 |
| 49b5fa9e2f | cv64a6_imafdc_sv39_sdtrig (ours) | NAPOT execute trigger never fires |
| aef009c4b3 | cv64a6_imafdc_mu (ours) | mstatus.SXL reads 64-bit on a core without S-mode |

`cv64a6_imafdc_sv39_sdtrig` is a benchmark config (`harness/cva6/configs/`): the default
config with Sdtrig/mcontrol6 enabled, since no shipped config enables triggers. On it, a
U-mode *load* matching an mcontrol6 NAPOT load trigger hangs even the fixed core (the load
never commits). Investigated: an RTL bug in the load unit's trigger-cancel path (wrong
trans_id after the load was already popped); details in `data/sdtrig_load_hang.md`.

## D. Still open

- Zkn on 32-bit configs (needs an RV32 harness): e6473dd61f

## Rejected

- 07732afe5d: debug_mode is X when DebugEn=0; Verilator is two-state, and the testharness reads tohost through the debug module, so a DebugEn=0 core never reports completion.

- 9ada1f383c: G-stage host PPN truncation only matters for physical addresses above 2^41; not reachable in the simulator memory map.

- 6b2d637595: pmpaddr63 out-of-bounds read; with 8 PMP entries there is no visible effect in simulation.
- 9f3a2992e2: single-step WFI needs an external debugger.
- c4c412a9f8, 37e2cb23ca: branch-predictor classification and flush; mispredictions are recovered, so the effect is performance only.
- 7b4689579e, 6cb200105f, 2544b85e4d: Zcmt/Zcmp, not enabled in any shipped config.
- a962460efd, a31b556c30: hpdcache XLEN wiring, accelerator dispatcher; not in the default build.
