#include "harness/hyp.h"
.option norvc
.text
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  csrw medeleg, zero
  li t0, 0x200000          # mstatus.TW (bit21)
  csrs mstatus, t0
  csrw mcounteren, zero
  li s0, 1
  ENTER_VS(vs_code)

trap_handler:
  csrr t3, mcause
  csrr t4, mstatus
  srli t5, t4, 38
  andi t5, t5, 3
  csrr t2, mtval2
  li a1, 10
  beq t3, a1, done
  bnez t2, bad
  li a1, 2
  bne t3, a1, bad
  li a1, 2
  bne t5, a1, bad
  addi s0, s0, 1
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
done:
  PASS
bad:
  slli a0, s0, 8
  or a0, a0, t3
  slli a0, a0, 8
  or a0, a0, t5
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt

.align 2
vs_code:
  wfi
  rdcycle a1
  rdtime a1
  ecall
HYP_TABLES
