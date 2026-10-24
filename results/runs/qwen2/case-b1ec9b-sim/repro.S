/*
 * Reproducer for: "MPRV is not cleared by an MRET that returns to S-mode".
 *
 * Privileged spec: when MRET is taken to a privilege level less privileged than
 * M-mode, MSTATUS.MPRV is written to 0.
 *
 * This core keeps MPRV live after such an MRET.  We exploit that:
 *
 *   1. Build a single-stage Sv39 table: one 1GiB leaf maps the whole program to
 *      [0x80000000, 0xC0000000).  Address A = 0xC0000000 (root index 3) is
 *      therefore unmapped, while it IS valid physical DRAM.
 *   2. Prime MSTATUS.MPRV=1 and MPP=S, then MRET into S-mode.  A conforming
 *      core clears MPRV here; the buggy core does not.
 *   3. From S-mode bounce back to M-mode with an ecall (M-mode cannot be entered
 *      by SRET; any S-mode exception lands at mtvec).  MPRV is unchanged by the
 *      trap.
 *   4. Back in M-mode keep MPP=S and load A:
 *        - MPRV correctly cleared  -> plain physical load of valid DRAM -> PASS
 *        - MPRV leaked across MRET -> access is translated as an S-mode access
 *          through satp, and A is unmapped -> load page fault -> trap -> FAIL
 */
#include "test.h"
#include "hyp.h"

  HYP_TABLES

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Sv39 root: 1GiB leaf at index 2 -> physical 0x80000000 (identity for the
   * program).  Anything at/virtual >= 0xC0000000 is left unmapped. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  la  t0, vs_root
  srli t0, t0, 12
  li  t1, (8 << 60)              /* satp mode = Sv39 */
  or  t0, t0, t1
  csrw satp, t0
  sfence.vma

  /* MPP=S, MPRV=1, then MRET to S-mode.  (MRET target = MPP = S.) */
  li   t0, (3 << 11)
  csrc mstatus, t0
  li   t0, (1 << 11)
  csrs mstatus, t0
  li   t0, 0x20000               /* MSTATUS.MPRV */
  csrs mstatus, t0
  la   t0, s_trap
  csrw mepc, t0
  mret

  .align 2
s_trap:
  /* S-mode: take a controlled exception that returns us to M-mode.  MPRV is not
   * touched by the trap. */
  ecall

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li   t1, 9                    /* 9 = environment call from S-mode (our bounce) */
  bne  t0, t1, fail_trap

  /* Back in M-mode.  MPRV must be 0.  Keep MPP=S so that, if MPRV wrongly
   * survived the MRET, this M-mode access is translated as S-mode through satp. */
  li   t0, (3 << 11)
  csrc mstatus, t0
  li   t0, (1 << 11)
  csrs mstatus, t0

  /* MPRV=0  -> physical load of valid DRAM, succeeds.
   * MPRV=1  -> S-mode translation; 0xC0000000 is unmapped -> load page fault. */
  li   a0, 0xc0000000
  ld   x5, 0(a0)
  PASS

fail_trap:
  FAIL(3)
