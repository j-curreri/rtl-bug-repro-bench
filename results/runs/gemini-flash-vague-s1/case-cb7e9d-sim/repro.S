#include "test.h"

  .globl test_main
  .globl trap_handler

  .align 2
trap_handler:
  /* Check mcause == 3 (Breakpoint exception from trigger action=0) */
  csrr t6, mcause
  li t5, 3
  bne t6, t5, bad_trap

  /* Verify mepc points to target_addr */
  csrr t6, mepc
  la t5, target_addr
  bne t6, t5, bad_trap

  /* Disable trigger 0 so execution can resume past target_addr */
  li t0, 0
  csrw tselect, t0
  li t0, 6
  slli t0, t0, 60
  csrw tdata1, t0
  li t0, 15
  slli t0, t0, 60
  csrw tdata1, t0
  csrw tdata1, zero

  /* Record that the trigger successfully fired */
  li s1, 1
  mret

bad_trap:
  FAIL(127)

test_main:
  PMP_ALLOW_ALL

  /* s1 tracks whether the trigger fired */
  li s1, 0

  /* Select trigger 0 */
  li t0, 0
  csrw tselect, t0

  /* Set tdata2 to an 8-byte naturally aligned power-of-two (NAPOT) range
   * covering target_addr. In NAPOT encoding, the 3 trailing ones indicate
   * an 8-byte range (2^3 = 8 bytes). */
  la t1, target_addr
  ori t1, t1, 7
  csrw tdata2, t1

  /* Configure mcontrol6:
   * type   = 6 (bits 63:60, mcontrol6)
   * match  = 1 (bits 10:7, NAPOT matching)
   * m      = 1 (bit 6, enable in M-mode)
   * execute= 1 (bit 2, match instruction address)
   * action = 0 (bits 15:12, breakpoint exception)
   * Value: (6 << 60) | (1 << 7) | (1 << 6) | (1 << 2) = (6 << 60) | 0xc4 */
  li t2, 6
  slli t2, t2, 60
  ori t2, t2, 0xc4
  csrw tdata1, t2

  /* Jump directly to the aligned target */
  j target_addr

  .align 3
target_addr:
  nop
  nop

  /* Check that the NAPOT trigger fired */
  li t0, 1
  bne s1, t0, trigger_did_not_fire

  PASS

trigger_did_not_fire:
  FAIL(1)
