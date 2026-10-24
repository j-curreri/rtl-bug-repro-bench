/* HLVX may read an execute-only G-stage page; a following plain HLV to the same page must
 * still raise a load guest-page fault (cause 21). GPA 0xC0000000 aliases physical
 * 0x80000000 through an execute-only G-stage leaf. */
#include "hyp.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, PTE_V | PTE_X | PTE_U | PTE_A)
  HGATP_ON
  csrw vsatp, zero
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  la a1, probe
  li t0, 0x40000000
  add a1, a1, t0
  hlvx.wu a2, (a1)
  la s1, after_hlvx            /* handler uses s1 to tell which access faulted */
after_hlvx:
  hlv.w a3, (a1)
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  la t0, after_hlvx
  bne s1, t0, 1f               /* HLVX itself faulted */
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 3f
  PASS
1: FAIL(1)
3: FAIL(3)

  .data
  .align 4
probe: .word 0x12345678
  HYP_TABLES
