#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* Clear the page tables so the unmapped G-stage region is reliably invalid. */
  la t0, g_root
  li t1, 2048
1:
  sd zero, 0(t0)
  addi t0, t0, 8
  addi t1, t1, -1
  bnez t1, 1b

  la t0, vs_root
  li t1, 512
2:
  sd zero, 0(t0)
  addi t0, t0, 8
  addi t1, t1, -1
  bnez t1, 2b

  /* G-stage: identity-map DRAM GPA 0x80000000..0xbfffffff.
     GPA 0x40000000 (the load target below) stays unmapped. */
  la t0, g_root
  li t1, 0x200000df       /* PPN(0x80000000) | V,R,W,X,U,A,D */
  sd t1, 16(t0)           /* root index 2 */

  /* VS-stage: map the executing DRAM region normally. */
  la t0, vs_root
  li t1, 0x200000cf
  sd t1, 16(t0)           /* VA 0x80000000..0xbfffffff -> same GPA */

  /* VA 0..0x3fffffff maps to GPA 0x40000000 with execute-only access.
     The load violates VS permissions, while its final G-stage translation
     also faults because G-stage root index 1 is invalid. */
  li t1, 0x100000c9       /* PPN(0x40000000) | V,X,A,D */
  sd t1, 0(t0)

  /* Install both translation stages, then enter virtual S mode. */
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)
  ENTER_VS(guest_start)

  .align 2
guest_start:
  li t0, 0x1000
  ld t1, 0(t0)
  FAIL(1)                 /* The load must trap. */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21               /* LOAD_GUEST_PAGE_FAULT */
  bne t0, t1, bad_cause
  PASS
bad_cause:
  FAIL(2)

HYP_TABLES
