#include "hyp.h"
  .option norvc
#define SETUP(k, vsf, gf) GIGA_LEAF(g_root, k, ((k) << 30), gf); GIGA_LEAF(vs_root, k, ((k) << 30), vsf)
#define SETUPP(k, gf) GIGA_LEAF(g_root, k, ((k) << 30), gf); RAW_PTE(vs_root, k, ((100 << 30) >> 12 << 10) | 1)
  .text
  .globl test_main

.macro DOLD k
  li t2, (\k<<30)
  ld t3, 0(t2)
.endm
.macro DOST k
  li t2, (\k<<30)
  sd t3, 0(t2)
.endm
.macro DOFE k
  li t2, (\k<<30)
  jalr ra, 0(t2)
.endm

test_main:
  li t0, ((0x40000000 >> 2) | 0x1ffffff)
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  li t0, 0x1f18
  csrw pmpcfg0, t0
  la s11, results
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  GIGA_LEAF(g_root, 1, 0x40000000, G_RWX)
  RAW_PTE(vs_root, 5, ((1 << 30) >> 12 << 10) | 1)
  RAW_PTE(vs_root, 6, ((1 << 30) >> 12 << 10) | 1)
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)
  la t0, 1f
  csrw mepc, t0
  la t0, trap_handler
  csrw mtvec, t0
  ENTER_VS(1f)
1:
  DOLD 5
  DOST 6
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr gp, mcause
  li s10, 10
  beq gp, s10, done
  sd gp, 0(s11)
  addi s11, s11, 8
  li s10, 12
  beq gp, s10, fetchf
  li s10, 20
  beq gp, s10, fetchf
  csrr gp, mepc
  addi gp, gp, 4
  csrw mepc, gp
  mret
fetchf:
  csrw mepc, ra
  mret
done:
  la s11, results
  la s10, expected
  li t5, 0
2:
  li t4, 2
  bge t5, t4, 3f
  ld t3, 0(s11)
  ld t4, 0(s10)
  bne t3, t4, 4f
  addi s11, s11, 8
  addi s10, s10, 8
  addi t5, t5, 1
  j 2b
3:
  PASS
4:
  slli t3, t3, 8
  or t3, t3, t5
  slli a0, t3, 1
  ori a0, a0, 1
  j _halt

  HYP_TABLES
  .data
  .align 3
results: .space 400
expected:
  .dword 5,7
