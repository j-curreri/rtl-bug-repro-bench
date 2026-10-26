#include "hyp.h"

/* Probe: two-stage translation. VS-mode loads go VA -> GPA -> HPA. The G-stage maps GPA
 * 0x40000000 (1 GiB) onto HPA 0x80000000, so VA 0x40300000 reaches HPA 0x80300000. Entry 0
 * denies HPA 0x80300000 (8 bytes); the load must fault whichever address it is reached by. */

#define T 0x80300000
#define RET_INSN 0x00008067

  HYP_TABLES

  .section .text
  .globl test_main
test_main:
  /* entry 7: NAPOT over all memory, RWX */
  li t0, -1
  csrw pmpaddr7, t0
  li t0, 0x1f
  slli t0, t0, 56
  csrw pmpcfg0, t0

  /* G-stage: GPA 0x40000000 and GPA 0x80000000 both map to HPA 0x80000000 */
  GIGA_LEAF(g_root, 1, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* VS-stage: VA 0x40000000 and VA 0x80000000 map to the same GPA */
  GIGA_LEAF(vs_root, 1, 0x40000000, VS_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)

  ENTER_VS(vs_main)

vs_main:
  .macro SETENT0 cfg
    li a0, ((T | 3) >> 2)
    li a1, ((0x1f << 56) | \cfg)
    li a7, 1
    ecall
  .endm

  .macro LDV id, va, expect
    la t5, last_cause
    sd zero, 0(t5)
    li t0, \va
    ld t1, 0(t0)
    la t5, last_cause
    ld t6, 0(t5)
    li t4, \expect
    bne t6, t4, 8f
    j 9f
8:  addi a0, t6, 100
  j _halt
9:
  .endm

  /* 1. entry 0 readable: both aliases succeed */
  SETENT0 0x00
  LDV 10, 0x40300000, 0
  LDV 11, 0x80300000, 0
  /* 2. entry 0 denied: both aliases fault */
  SETENT0 0x18
  LDV 20, 0x40300000, 5
  LDV 21, 0x80300000, 5
  PASS

  .section .data
  .align 3
last_cause: .dword 0

  .section .text
  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 10
  beq t6, t5, 1f
  la t5, last_cause
  sd t6, 0(t5)
  csrr t6, mepc
  addi t6, t6, 4
  csrw mepc, t6
  mret
1:
  csrw pmpaddr0, a0
  csrw pmpcfg0, a1
  csrr t6, mepc
  addi t6, t6, 4
  csrw mepc, t6
  mret
