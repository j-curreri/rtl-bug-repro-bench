/* VS-mode fetch at guest-physical address 0x40_8000_0000 (bit 38 set) with
 * vsatp = Bare and G-stage Sv39x4 on. The GPA is valid (41-bit, zero-extended)
 * and G-stage maps it to host 0x80000000, so the fetch must succeed. */
#include "hyp.h"

#define ALIAS_OFF 0x4000000000

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)       /* GPA 0x0080000000 -> 0x80000000 */
  GIGA_LEAF(g_root, 0x102, 0x80000000, G_RWX)   /* GPA 0x4080000000 -> 0x80000000 */
  csrw vsatp, zero
  HGATP_ON
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  la t0, vs_code
  li t1, ALIAS_OFF
  add t0, t0, t1
  csrw mepc, t0
  mret

  .align 2
vs_code:
  li a0, 0x5a
  ecall
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 10                 /* environment call from VS-mode */
  bne t6, t5, 1f
  li t5, 0x5a
  bne a0, t5, 2f
  csrr t4, mepc
  la t3, vs_code
  li t1, ALIAS_OFF
  add t3, t3, t1
  addi t3, t3, 4            /* li a0,0x5a is 1 compressed or 4-byte insn; check range */
  bltu t3, t4, 2f
  PASS
1:
  FAIL(3)
2:
  FAIL(4)

  HYP_TABLES
