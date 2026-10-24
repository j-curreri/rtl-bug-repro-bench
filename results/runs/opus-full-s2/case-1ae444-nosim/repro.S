/* mtval must be written with zero when a machine-mode interrupt is taken.
 * Take M-mode interrupts (software via CLINT msip, timer via CLINT mtimecmp)
 * on instructions whose decode-stage tval would be nonzero (plain ALU op ->
 * instruction bits, ebreak -> pc) and check mtval == 0 in the handler. */
#include "test.h"

#define CLINT_MSIP      0x02000000
#define CLINT_MTIMECMP  0x02004000

  .option norvc
  .text
  .globl test_main
test_main:
  csrw mie, zero
  csrci mstatus, 8

  /* ---- case 1: software interrupt on a plain instruction ---- */
  li s2, 1
  la s1, 2f
  li t0, -1; csrw mtval, t0
  li t0, CLINT_MSIP
  li t1, 1
  sw t1, 0(t0)
1:csrr t0, mip
  andi t0, t0, (1 << 3)
  beqz t0, 1b
  li t0, (1 << 3)
  csrw mie, t0
  csrsi mstatus, 8
  addi t2, t2, 0x7ff
  addi t2, t2, 0x7ff
  addi t2, t2, 0x7ff
  addi t2, t2, 0x7ff
1:j 1b
2:

  /* ---- case 2: software interrupt on ebreak ---- */
  li s2, 2
  la s1, 2f
  li t0, -1; csrw mtval, t0
  li t0, CLINT_MSIP
  li t1, 1
  sw t1, 0(t0)
1:csrr t0, mip
  andi t0, t0, (1 << 3)
  beqz t0, 1b
  li t0, (1 << 3)
  csrw mie, t0
  csrsi mstatus, 8
  ebreak
  ebreak
  ebreak
1:j 1b
2:

  /* ---- case 3: timer interrupt on a plain instruction ---- */
  li s2, 3
  la s1, 2f
  li t0, -1; csrw mtval, t0
  li t0, CLINT_MTIMECMP
  sd zero, 0(t0)
1:csrr t0, mip
  andi t0, t0, (1 << 7)
  beqz t0, 1b
  li t0, (1 << 7)
  csrw mie, t0
  csrsi mstatus, 8
  xori t2, t2, 0x555
  xori t2, t2, 0x555
  xori t2, t2, 0x555
1:j 1b
2:

  /* ---- case 4: timer interrupt on ebreak ---- */
  li s2, 4
  la s1, 2f
  li t0, -1; csrw mtval, t0
  li t0, CLINT_MTIMECMP
  sd zero, 0(t0)
1:csrr t0, mip
  andi t0, t0, (1 << 7)
  beqz t0, 1b
  li t0, (1 << 7)
  csrw mie, t0
  csrsi mstatus, 8
  ebreak
  ebreak
  ebreak
1:j 1b
2:

  PASS

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  bltz t0, 1f
  /* synchronous: tolerate a breakpoint (interrupt arrived late), else fail */
  li t1, 3
  bne t0, t1, 9f
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
9:FAIL(100)

1:csrr t1, mtval
  /* quiesce interrupt sources */
  csrw mie, zero
  li t2, CLINT_MSIP
  sw zero, 0(t2)
  li t2, CLINT_MTIMECMP
  li t3, -1
  sd t3, 0(t2)
  bnez t1, 8f
  jr s1               /* stay in M-mode with MIE cleared by the trap */
8:mv a0, s2
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt
