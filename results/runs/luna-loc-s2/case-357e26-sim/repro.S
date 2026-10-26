#include "test.h"

  .section .text
  .option rvc
  .align 2
  .globl test_main
test_main:
  /* G=1 makes a NAPOT region at least 16 bytes (pmpaddr bit 0 reads as 1). */
  li t0, 0x1c               /* NAPOT + X */
  csrw pmpcfg0, t0
  la t0, user_start
  srli t1, t0, 2
  csrw pmpaddr0, t1
  ENTER_MODE(0, user_start)

  .align 4
  .globl user_start
user_start:
  c.nop                     /* +0 */
  c.nop                     /* +2 */
  c.nop                     /* +4 */
  c.nop                     /* +6 */
  c.nop                     /* +8 */
  c.nop                     /* +10 */
  c.nop                     /* +12 */
user_cross:
  .option norvc
  .4byte 0x00000073          /* 32-bit ecall at +14 crosses the 16-byte PMP boundary */
  .option rvc

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 1                  /* instruction access fault */
  bne t0, t1, wrong_cause
  csrr t0, mepc
  la t1, user_cross
  bne t0, t1, wrong_pc
  PASS
wrong_cause:
  FAIL(2)
wrong_pc:
  FAIL(3)
