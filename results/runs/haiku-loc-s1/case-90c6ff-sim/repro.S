#include "hyp.h"

/* Execute-only page (X=1, R=0). With MXR=1 a load is allowed and fills the DTLB.
 * After MXR is cleared the same load must raise a load page fault (cause 13). */
  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* VA 0x80000000 -> PA 0x80000000, identity map for code and data. */
  GIGA_LEAF(vs_root, 2, 0x80000000, PTE_V | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D)
  /* VA 0x40000000 -> PA 0x80000000, execute-only (no R). */
  GIGA_LEAF(vs_root, 1, 0x80000000, PTE_V | PTE_X | PTE_A)
  la t0, vs_root
  srli t0, t0, 12
  li t1, SATP_SV39
  or t0, t0, t1
  csrw satp, t0
  sfence.vma
  la t0, s_code
  csrw mepc, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11)
  csrs mstatus, t0
  mret

  .align 3
s_code:
  /* MXR=1: load from the execute-only alias is permitted and fills the DTLB. */
  li t0, 0x80000
  csrs sstatus, t0
  la t1, probe
  li t2, 0x40000000
  sub t1, t1, t2
  ld t3, 0(t1)
  /* MXR=0: the same load must fault. */
  csrc sstatus, t0
  li s11, 1
  ld t3, 0(t1)
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  beqz s11, 2f
  csrr t0, mcause
  li t1, 13
  bne t0, t1, 2f
  PASS
2:
  csrr t0, mcause
  slli t0, t0, 1
  ori t0, t0, 1
  mv a0, t0
  j _halt

  HYP_TABLES
  .align 3
probe: .dword 0x1234
