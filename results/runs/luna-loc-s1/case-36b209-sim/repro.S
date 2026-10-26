#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Build a G-stage tree for the first GiB of DRAM, using 2-MiB leaves.
     The leaf containing probe_page is changed to execute-only below. */
  la t0, g_root
  li t1, 2048
1:
  sd zero, 0(t0)
  addi t0, t0, 8
  addi t1, t1, -1
  bnez t1, 1b

  la t0, g_root
  la t1, g_l1
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, PTE_V
  sd t1, 16(t0)                 /* root index 2: GPA 0x80000000 */

  /* Fill all 2-MiB G-stage leaves covering the first GiB of DRAM. */
  la t0, g_l1
  li t1, 0
2:
  slli t2, t1, 21
  li t3, 0x80000000
  add t2, t2, t3
  srli t2, t2, 2                /* PPN shifted into PTE position */
  ori t2, t2, G_RWX
  slli t3, t1, 3
  add t3, t3, t0
  sd t2, 0(t3)
  addi t1, t1, 1
  li t3, 512
  bltu t1, t3, 2b

  /* Replace the 2-MiB leaf containing probe_page with an X-only leaf. */
  la t0, probe_page
  srli t1, t0, 21
  andi t1, t1, 511
  slli t1, t1, 3
  la t2, g_l1
  add t1, t1, t2
  srli t0, t0, 21
  slli t0, t0, 21
  srli t0, t0, 2
  ori t0, t0, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
  sd t0, 0(t1)

  /* The VS-stage root maps VA 0x80000000..0xbfffffff identically. */
  la t0, vs_root
  li t1, 512
3:
  sd zero, 0(t0)
  addi t0, t0, 8
  addi t1, t1, -1
  bnez t1, 3b
  li t1, ((0x80000000 >> 12) << 10)
  ori t1, t1, (VS_RWX | PTE_U)
  la t0, vs_root
  sd t1, 16(t0)                 /* VA/GPA base is 1-GiB aligned */

  /* Machine-mode setup of two-stage translation. */
  la t0, g_root
  srli t0, t0, 12
  li t1, SATP_SV39
  or t0, t0, t1
  csrw hgatp, t0
  hfence.gvma
  la t0, vs_root
  VSATP_ON(t0)

  /* HLVX is a hypervisor instruction, so execute it in HS-mode while it
     explicitly accesses the VS-stage address space. */
  ENTER_MODE(1, guest)

  .align 2
guest:
  la t0, probe_page
  /* HLVX uses execute permission at VS-stage, but must use read permission
     at G-stage. The G-stage leaf above intentionally has X=1 and R=0. */
  hlvx.hu t1, (t0)
  FAIL(1)                        /* Buggy core incorrectly completes load */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21                      /* load guest-page fault */
  beq t0, t1, 4f
  FAIL(127)
4:
  csrr t2, htval
  la t3, probe_page
  srli t3, t3, 2
  bne t2, t3, 5f
  PASS
5:
  FAIL(2)

  HYP_TABLES
  .align 12
g_l1: .space 4096

  .section .data.probe,"aw",@progbits
  .align 22
probe_page:
  .dword 0x123456789abcdef0
