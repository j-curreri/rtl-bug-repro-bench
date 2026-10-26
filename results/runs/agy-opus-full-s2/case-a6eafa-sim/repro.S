/* HLVX: the VS-stage PTE fetch is an implicit *load* for G-stage checks.
 * The VS-stage root table lives in a guest-physical GiB that the G-stage maps
 * execute-only (no R). HLVX must therefore raise a load guest-page fault
 * (mcause 21) during the VS-stage walk. */
#include "test.h"
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: GPA 0x8000_0000 GiB -> PA 0x8000_0000, RWX (code/data). */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* G-stage: GPA 0xC000_0000 GiB -> PA 0x8000_0000, execute-only. */
  GIGA_LEAF(g_root, 3, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))

  /* VS-stage: VA 0x8000_0000 GiB -> GPA 0x8000_0000, RWX (supervisor). */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  HGATP_ON

  /* vsatp root = GPA alias of vs_root inside the execute-only GiB. */
  la t2, vs_root
  li t3, 0x40000000
  add t2, t2, t3
  VSATP_ON(t2)

  /* HLVX acts as VS-mode supervisor access. */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* Make sure MXR is clear. */
  li t0, (1 << 19)
  csrc mstatus, t0

  la a1, target
  li s0, 0
  hlvx.wu a2, (a1)
  /* Should not get here: the walk must fault. */
  FAIL(1)

after_trap:
  li t0, 21
  bne s1, t0, bad_cause
  PASS

bad_cause:
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr s1, mcause
  csrr s2, mtval2
  bnez s0, nested
  li s0, 1
  la t0, after_trap
  csrw mepc, t0
  li t0, (3 << 11)
  csrs mstatus, t0      /* stay in M-mode */
  li t0, MSTATUS_MPV
  csrc mstatus, t0
  mret
nested:
  FAIL(4)

  .data
  .align 3
target:
  .word 0x00000013

  HYP_TABLES
