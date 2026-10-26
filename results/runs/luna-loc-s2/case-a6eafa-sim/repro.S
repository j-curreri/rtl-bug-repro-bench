#include "test.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Build an Sv39 root with a 1 GiB identity mapping for DRAM at 0x80000000. */
  la t0, page_root
  li t1, 512
1:
  sd zero, 0(t0)
  addi t0, t0, 8
  addi t1, t1, -1
  bnez t1, 1b

  la t0, page_root
  li t1, 0x200000cf       /* PPN=0x80000, V/R/W/X/A/D */
  sd t1, 16(t0)           /* VPN[2] for 0x80000000 is 2 */

  la t0, page_root
  srli t0, t0, 12
  li t1, (8 << 60)        /* Sv39 */
  or t0, t0, t1
  csrw satp, t0
  sfence.vma x0, x0

  /* MBE is WARL supported here; CVA6 mirrors it into SBE. PTEs remain LE. */
  li t0, (1 << 37)
  csrs mstatus, t0
  ENTER_MODE(1, s_test)

s_test:
  /* Fetching this instruction requires a page walk through the LE PTE above. */
  ecall

  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 9                 /* the intentional S-mode ecall */
  beq t0, t1, 2f
  li t0, (1 << 37)
  csrc mstatus, t0          /* keep the tohost write little-endian */
  FAIL(1)
2:
  li t0, (1 << 37)
  csrc mstatus, t0
  PASS

  .section .data
  .align 12
page_root:
  .space 4096
