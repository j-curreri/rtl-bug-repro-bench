#include "hyp.h"

/* G-stage maps guest-physical 0x80000000 (1 GiB) execute-only. From HS-mode,
 * HLVX.WU reads a word (allowed: X counts as R for HLVX), then HLV.W reads the
 * same word. The HLV.W must raise a load guest-page fault (cause 21). */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))
  HGATP_ON
  csrw vsatp, zero
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  li s0, 0                 /* stage marker */
  ENTER_MODE(1, hs_code)

hs_code:
  la a1, target
  li s0, 1
  hlvx.wu a2, (a1)         /* must succeed */
  li t0, 0x12345678
  bne a2, t0, hlvx_bad
  li s0, 2
hlv_insn:
  hlv.w a3, (a1)           /* must fault with load guest-page fault */
  li s0, 3
  ecall                    /* reached only if HLV succeeded */
hlvx_bad:
  li s0, 4
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t0, 2
  bne s0, t0, 1f
  li t0, 21
  bne t6, t0, 2f
  csrr t0, mepc
  la t1, hlv_insn
  bne t0, t1, 2f
  PASS
1:
  li t0, 3
  bne s0, t0, 2f
  FAIL(1)                  /* HLV succeeded on execute-only guest page */
2:
  FAIL(2)

  .data
  .align 3
target: .word 0x12345678

HYP_TABLES
