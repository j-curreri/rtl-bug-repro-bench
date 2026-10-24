#include "hyp.h"

/* G-stage maps guest-physical 0xC0000000 -> 0x80000000 execute-only.
 * HLVX.WU from it must succeed; a following HLV.W must raise a load
 * guest-page fault (cause 21). */
#define G_XO (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
#define GPA(sym) ((sym) - 0x80000000 + 0xC0000000)

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, G_XO)
  csrw vsatp, zero
  HGATP_ON
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  li s0, 0              /* number of guest-page faults seen */
  li s1, 0              /* set if HLVX misbehaves */
  ENTER_MODE(1, hs_code)

hs_code:
  la a1, magic
  li t0, 0x40000000
  add a1, a1, t0        /* guest-physical alias in the X-only gigapage */
  hlvx.wu a2, (a1)
  li t0, 0x1234abcd
  bne a2, t0, bad_hlvx
  li a3, 0
  hlv.w a3, (a1)        /* must trap with load guest-page fault */
  ecall

bad_hlvx:
  li s1, 1
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21
  beq t0, t1, gpf
  li t1, 9              /* ecall from HS-mode: done */
  bne t0, t1, unexpected
  bnez s1, fail_hlvx
  li t1, 1
  bne s0, t1, fail_nofault
  PASS
fail_hlvx:
  FAIL(2)
fail_nofault:
  FAIL(1)
unexpected:
  FAIL(3)
gpf:
  addi s0, s0, 1
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret

  .data
  .align 3
magic: .word 0x1234abcd

  HYP_TABLES
