#include "test.h"

  .section .text
  .globl test_main
test_main:
  csrw satp, zero
  csrw medeleg, zero

  /* Entry 0: OFF, pmpaddr0 = region_start >> 2 (TOR lower bound = region_start). */
  la t0, region_start
  srli t0, t0, 2
  csrw pmpaddr0, t0

  /* Entry 1: TOR with no RWX permissions, pmpaddr1 = (region_end >> 2) | 1.
   * For G=1 (8-byte grain), bit 0 of pmpaddr1 does not affect TOR matching,
   * so Entry 1 must protect [region_start, region_end). */
  la t0, region_end
  srli t0, t0, 2
  ori t0, t0, 1
  csrw pmpaddr1, t0

  /* Entry 2: NAPOT RWX covering all physical memory. */
  li t0, -1
  csrw pmpaddr2, t0

  /* pmpcfg0: entry0 = OFF (0x00), entry1 = TOR no-RWX (0x08), entry2 = NAPOT RWX (0x1f). */
  li t0, 0x001f0800
  csrw pmpcfg0, t0
  sfence.vma

  li a7, 99
  la a0, region_end
  ENTER_MODE(0, u_entry)

u_entry:
  lbu t1, 0(a0)
  li t2, 0x5a
  bne t1, t2, u_wrong_val
  li a7, 0
u_ecall:
  ecall

u_wrong_val:
  li a7, 2
  ecall

  .globl trap_handler
  .balign 4
trap_handler:
  csrr t0, mcause
  li t1, 8
  bne t0, t1, fail_trap
  csrr t0, mepc
  la t1, u_ecall
  bne t0, t1, fail_mepc
  bnez a7, fail_val
  PASS

fail_trap:
  FAIL(1)
fail_mepc:
  FAIL(2)
fail_val:
  FAIL(3)

  .section .data
  .balign 4096
region_start:
  .space 4096, 0xaa
region_end:
  .byte 0x5a
  .balign 4096
