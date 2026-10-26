#include "test.h"

/*
 * MRET from M to S must clear MPRV.  S-mode runs through explicit 4 KiB
 * mappings.  The probe address is valid physical DRAM, but deliberately has
 * no virtual mapping.  Thus an M-mode load succeeds when MRET cleared MPRV,
 * and faults if the load is still translated/permission-checked.
 */

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Store a known value in the otherwise unused L1 table slot at 0x80004008. */
  li t0, 0x80004008
  li t1, 0x13579bdf
  sd t1, 0(t0)
  mv t3, t0

  /* Sv39 root[2] -> level-1 table[0] -> 4 KiB level-0 mappings. */
  la t0, root_page_table
  la t1, level1_table
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, 1             /* V */
  sd t1, 16(t0)             /* root index 2 */

  la t0, level1_table
  la t1, level0_table
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, 1             /* V */
  sd t1, 0(t0)               /* level-1 index 0 */

  /* Map the harness and code pages; leave page 4's probe VA unmapped. */
  la t0, level0_table
  li t1, 0x80000000
  li t2, 0
1:
  srli t4, t1, 12
  slli t4, t4, 10
  ori t4, t4, 0xcf           /* V/R/W/X/A/D; supervisor only */
  sd t4, 0(t0)
  addi t0, t0, 8
  li t4, 0x1000
  add t1, t1, t4
  addi t2, t2, 1
  li t4, 3
  blt t2, t4, 1b

  la t0, root_page_table
  srli t0, t0, 12
  li t1, (8 << 60)
  or t0, t0, t1
  csrw satp, t0
  sfence.vma

  /* Return to S with MPRV set: MRET is required to clear it. */
  li t0, ((1 << 11) | (1 << 17))
  csrs mstatus, t0
  la t0, supervisor_entry
  csrw mepc, t0
  mret

  .align 2
supervisor_entry:
  ecall
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t2, 9                   /* Environment call from S-mode */
  bne t0, t2, 2f             /* An unexpected trap */
  /* Probe immediately after identifying the expected trap. */
  ld t1, 0(t3)
  li t2, 0x13579bdf
  bne t1, t2, 3f
  PASS
2:
  FAIL(2)
3:
  FAIL(3)

  .section .data
  .align 12
root_page_table:
  .zero 4096
  .align 12
level1_table:
  .zero 4096
  .align 12
level0_table:
  .zero 4096
