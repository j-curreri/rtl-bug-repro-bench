#include "test.h"

/* HLVX.HU may read an execute-only G-stage mapping. A plain HLV.HU to the
 * same guest address must still fault, even though HLVX filled the DTLB. */

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Map GPA 0x40000000 to DRAM as execute-only. Map GPA 0x80000000, where
   * the VS page table lives, as RWX so the implicit page-table read works. */
  la t0, g_root
  li t1, 0x20000000 | 0xd9       /* PPN(0x80000000) | V,X,U,A,D */
  sd t1, 8(t0)                    /* G-stage root index 1 */
  li t1, 0x20000000 | 0xcf       /* PPN(0x80000000) | V,R,W,X,U,A,D */
  sd t1, 16(t0)                   /* G-stage root index 2 */

  /* VS-stage VA 0x40000000 -> GPA 0x40000000, 1 GiB leaf. */
  la t0, vs_root
  li t1, 0x10000000 | 0xcf       /* PPN(0x40000000) | V,R,W,X,A,D */
  sd t1, 8(t0)                    /* VS-stage root index 1 */

  /* Activate G translation and arrange for HLV instructions in HS mode to
   * use S privilege for their implicit guest access. */
  la t0, g_root
  srli t0, t0, 12
  li t1, (8 << 60)
  or t0, t0, t1
  csrw hgatp, t0
  hfence.gvma
  li t0, (1 << 8)                 /* hstatus.SPVP = S */
  csrs hstatus, t0
  la t0, vs_root
  srli t0, t0, 12
  li t1, (8 << 60)
  or t0, t0, t1
  csrw vsatp, t0
  hfence.vvma

  ENTER_MODE(1, hs_main)

hs_main:
  la t0, hs_trap_handler
  csrw stvec, t0
  li s0, 0x40000000
  /* HLVX.HU is encoded by the assembler when the H extension is enabled. */
  hlvx.hu t1, (s0)
  la t0, expected_fault
  li t1, 1
  sw t1, 0(t0)                    /* phase 1: HLVX completed successfully */

  /* A regular HLV.HU to the now-cached execute-only translation must fault
   * at G-stage. If it returns, the DTLB hit path skipped that permission. */
  .option push
  .option norvc
  hlv.hu t2, (s0)
  .option pop
  la t0, expected_fault
  lw t1, 0(t0)
  li t2, 2
  beq t1, t2, expected_fault_seen
  FAIL(1)
expected_fault_seen:
  PASS

  .align 2
hs_trap_handler:
  csrr t0, scause
  li t1, 21                       /* load guest-page fault */
  bne t0, t1, unexpected_trap
  la t0, expected_fault
  lw t1, 0(t0)
  li t2, 1
  bne t1, t2, unexpected_trap     /* only the plain HLV may fault */
  li t1, 2
  sw t1, 0(t0)
  csrr t0, sepc
  addi t0, t0, 4                  /* resume after the faulting HLV.HU */
  csrw sepc, t0
  sret

  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21                       /* load guest-page fault */
  bne t0, t1, unexpected_trap
  la t0, expected_fault
  lw t1, 0(t0)
  li t2, 1
  bne t1, t2, unexpected_trap
  li t1, 2
  sw t1, 0(t0)
  csrr t0, mepc
  addi t0, t0, 4                  /* resume after the faulting HLV.HU */
  csrw mepc, t0
  mret
unexpected_trap:
  FAIL(127)

  .section .data
  .align 14
g_root:
  .space 16384
  .align 12
vs_root:
  .space 4096
expected_fault:
  .word 0

