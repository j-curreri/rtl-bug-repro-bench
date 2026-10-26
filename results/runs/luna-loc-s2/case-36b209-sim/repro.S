#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Identity map the DRAM region containing this program with one Sv39 leaf. */
  la t0, root_page
  addi t0, t0, 16             /* root entry for VA 0x80000000 (VPN[2] = 2) */
  li t1, 0x200000cf           /* PPN 0x80000, V/R/W/X/A/D */
  sd t1, 0(t0)

  la t0, root_page
  srli t0, t0, 12
  li t1, (8 << 60)             /* Sv39 */
  or t0, t0, t1
  csrw satp, t0
  sfence.vma zero, zero

  /*
   * The architecture requires implicit page-table reads to be little-endian,
   * independently of MBE/SBE. On this core MBE is also mirrored to SBE, so
   * the next S-mode instruction fetch exercises the PTW with big-endian mode
   * selected while the PTE above remains little-endian in memory.
   */
  li t0, (1 << 37)
  csrs mstatus, t0
  ENTER_MODE(1, translated_code)

translated_code:
  lbu t0, translated_byte
  li t1, 0x5a
  bne t0, t1, failed_data
  PASS

failed_data:
  FAIL(2)

  .globl trap_handler
trap_handler:
  FAIL(1)

  .section .data
translated_byte:
  .byte 0x5a

  .section .bss
  .align 12
root_page:
  .space 4096
