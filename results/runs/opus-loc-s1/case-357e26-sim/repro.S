#include "test.h"

/* NA4 PMP mode must match exactly one 4-byte word. Entry 0 is NA4 over
 * `target` with no permissions; entry 1 grants RWX everywhere. A U-mode load
 * from `target` must raise a load access fault, while the next word must not. */

  .section .text
  .globl test_main
test_main:
  li s1, 0                    /* faults on target */
  li s2, 0                    /* faults on target+4 */
  la t0, target
  srli t0, t0, 2
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  li t0, 0x1f10               /* entry0: NA4, ---; entry1: NAPOT, RWX */
  csrw pmpcfg0, t0
  sfence.vma
  ENTER_MODE(0, user_code)

  .option push
  .option norvc
user_code:
  la a1, target
fault_pc:
  lw a2, 0(a1)                /* must fault */
  la a1, target
  lw a3, 4(a1)                /* must not fault */
  ecall
  .option pop

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 5
  beq t0, t1, load_fault
  li t1, 8
  beq t0, t1, user_done
  FAIL(127)
load_fault:
  csrr t0, mepc
  la t1, fault_pc
  bne t0, t1, 1f
  addi s1, s1, 1
  j 2f
1:
  addi s2, s2, 1
2:
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret

user_done:
  li t0, 1
  bne s1, t0, fail1
  bnez s2, fail2
  PASS
fail1:
  FAIL(1)
fail2:
  FAIL(2)

  .data
  .align 4
  .dword 0
target:
  .word 0x11111111
  .word 0x22222222
  .dword 0
