#include "test.h"

/* Sv39 page-table flags. */
#define PTE_V 0x001
#define PTE_R 0x002
#define PTE_X 0x008
#define PTE_A 0x040

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* The S-mode code is in the linked DRAM page. Set up a single Sv39
     branch for that page and the probe pages. */
  la t0, s_root
  la t1, s_middle
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, PTE_V
  sd t1, 16(t0)                /* root[2], VA 0x80000000.. */

  la t0, s_middle
  la t1, s_leaf
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, PTE_V
  sd t1, 0(t0)                 /* middle[0] */

  /* Map the S entry point's page identity with execute permission. */
  la t0, s_entry
  srli t1, t0, 12
  andi t1, t1, 0x1ff
  srli t2, t0, 12
  slli t2, t2, 10
  ori t2, t2, (PTE_V | PTE_R | PTE_X | PTE_A)
  la t3, s_leaf
  slli t1, t1, 3
  add t3, t3, t1
  sd t2, 0(t3)

  /* The probe's VA is backed by the other page in S mode. */
  la t0, probe_direct
  srli t1, t0, 12
  andi t1, t1, 0x1ff
  la t2, probe_alias
  srli t2, t2, 12
  slli t2, t2, 10
  ori t2, t2, (PTE_V | PTE_R | PTE_A)
  la t3, s_leaf
  slli t1, t1, 3
  add t3, t3, t1
  sd t2, 0(t3)

  la t0, s_root
  srli t0, t0, 12
  li t1, (8 << 60)           /* satp.MODE = Sv39, ASID = 0 */
  or t0, t0, t1
  csrw satp, t0
  sfence.vma x0, x0

  /* MPRV must be cleared by this MRET because MPP=S. The S-mode ecall
     then traps into M, where the load in trap_handler tests that rule. */
  li t0, (1 << 17)
  csrs mstatus, t0
  ENTER_MODE(1, s_entry)

  /* Reaching here means the ecall unexpectedly returned. */
  FAIL(2)

  .align 2
  .globl s_entry
s_entry:
  ecall
1: j 1b

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 9                   /* environment call from S-mode */
  bne t0, t1, trap_fail

  /* With MPRV correctly cleared, this is a bare M-mode load and reads
     probe_direct. If stale MPRV applies S translation, it reads alias. */
  la t0, probe_direct
  ld t1, 0(t0)
  li t2, 0x1122334455667788
  bne t1, t2, trap_fail
  PASS

trap_fail:
  FAIL(1)

  .section .data
  .align 12
probe_direct:
  .dword 0x1122334455667788
  .align 12
probe_alias:
  .dword 0x8877665544332211

  .section .bss
  .align 12
s_root:
  .space 4096
  .align 12
s_middle:
  .space 4096
  .align 12
s_leaf:
  .space 4096
