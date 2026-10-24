#include "harness/hyp.h"

  .text
  .globl test_main
test_main:
  la t0, handler
  csrw mtvec, t0
  PMP_ALLOW_ALL
  /* G-stage: gigapage 2 (0x80000000) execute-only, user */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))
  HGATP_ON
  csrw vsatp, zero
  la t2, hdata
  hlvx.wu a1, (t2)      /* allowed: execute-only readable by HLVX */
hlv_insn: hlv.w a2, (t2)
  FAIL(1)

  .align 2
handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, bad
  csrr t0, mepc
  la t1, hlv_insn
  bne t0, t1, bad
  PASS
bad:
  FAIL(2)

  HYP_TABLES
  .align 3
hdata: .dword 0x1234
