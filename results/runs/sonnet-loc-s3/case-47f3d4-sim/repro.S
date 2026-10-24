#include "test.h"
.option norvc
.globl test_main
.globl trap_handler
trap_handler:
  csrr t5, mcause
  mv s9, t5
  csrr t6, mepc
  addi t6, t6, 4
  csrw mepc, t6
  mret

.macro CHK bit, reg, val
  li t1, \val
  beq \reg, t1, 1f
  li t1, (1<<\bit)
  or s0, s0, t1
1:
.endm

test_main:
  li s0, 0
  # 0: mie mask
  li t0, -1
  csrw mie, t0
  csrr t2, mie
  CHK 0, t2, 0x888
  csrw mie, zero
  # 1: mstatus MPP = S (01) is illegal -> keep previous
  li t0, 0x1800
  csrc mstatus, t0
  li t0, 0x0800
  csrs mstatus, t0
  csrr t2, mstatus
  srli t2, t2, 11
  andi t2, t2, 3
  CHK 1, t2, 0
  # 2: mepc
  li t0, 0x80001235
  csrw mepc, t0
  csrr t2, mepc
  li t3, 0x80001234
  CHK 2, t2, 0x80001234
  # 3: mcause
  li t0, -1
  csrw mcause, t0
  csrr t2, mcause
  srli t3, t2, 63
  CHK 3, t3, 1
  slli t2, t2, 1
  CHK 4, t2, 0x3e
  # 5: mcounteren/inhibit
  li t0, -1
  csrw mcounteren, t0
  csrr t2, mcounteren
  li t3, 0xffffffff
  CHK 5, t2, 0xffffffff
  # 6: mscratch / mtvec
  li t0, 0x80001001
  csrw mtvec, t0
  csrr t2, mtvec
  la t0, trap_handler
  csrw mtvec, t0
  # 7: ecall M
  li s9, 0
  ecall
  CHK 7, s9, 11
  # 8: mstatus MIE/MPIE after trap
  li t0, 8
  csrs mstatus, t0
  ecall
  csrr t2, mstatus
  andi t2, t2, 0x88
  CHK 8, t2, 0x80
  # 9: after mret, mie restored
  csrr t2, mstatus
  # 10: U-mode counter access with mcounteren=-1
  li s9, 0
  li t0, -1
  csrw mcounteren, t0
  PMP_ALLOW_ALL
  ENTER_MODE(0, umode)
umode:
  csrr t2, cycle
  csrr t2, instret
  ecall
back:
  CHK 10, s9, 8
  # note: we're in U-mode; ecall goes to M handler which returns to U
  # finish via ecall with a0 trick not available; use tohost directly
  slli a0, s0, 1
  ori a0, a0, 1
  j _halt
