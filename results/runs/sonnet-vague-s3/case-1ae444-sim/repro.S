#include "test.h"
  .globl test_main
  .globl trap_handler
  .align 2
trap_handler:
  csrr t1, mcause
  bgez t1, sync
  li t1, 0x02000000
  sw zero, 0(t1)
  csrr s4, mcause
  csrr s5, mstatus
  csrr s6, mepc
  csrr s1, mtval
  la t1, sA_done
  csrw mepc, t1
  mret
sync:
  addi s0, s0, 1
  li t1, 1
  beq s0, t1, phaseB
  j check
phaseB:
  li t1, 2
  csrs mip, t1          # SSIP, delegated to S
  la t1, sB
  csrw mepc, t1
  li t1, 0x1800
  csrc mstatus, t1
  li t1, 0x800
  csrs mstatus, t1
  mret
  .align 2
strap:
  csrr s7, scause
  csrr s8, sstatus
  csrr s9, sepc
  li t1, 2
  csrc sip, t1
  ecall
check:
  # phase A: M interrupt from S mode
  li t0, 1
  slli t0, t0, 63
  addi t0, t0, 3
  bne s4, t0, f1
  bnez s1, f1
  srli t0, s5, 11
  andi t0, t0, 3
  addi t0, t0, -1
  bnez t0, f2          # mpp == S
  srli t0, s5, 7
  andi t0, t0, 1
  bnez t0, f3          # mpie == 0 (MIE was 0)
  la t0, smode
  bltu s6, t0, f4
  la t0, sA_done
  bgtu s6, t0, f4
  # phase B: delegated SSI
  li t0, 1
  slli t0, t0, 63
  addi t0, t0, 1
  bne s7, t0, f5       # scause
  srli t0, s8, 8
  andi t0, t0, 1
  beqz t0, f6          # spp must be 1
  srli t0, s8, 5
  andi t0, t0, 1
  beqz t0, f7          # spie must be 1
  srli t0, s8, 1
  andi t0, t0, 1
  bnez t0, f8          # sie must be 0
  la t0, sB
  bltu s9, t0, f9
  la t0, sloopB
  bgtu s9, t0, f9
  PASS
f1: FAIL(1)
f2: FAIL(2)
f3: FAIL(3)
f4: FAIL(4)
f5: FAIL(5)
f6: FAIL(6)
f7: FAIL(7)
f8: FAIL(8)
f9: FAIL(10)
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  PMP_ALLOW_ALL
  li s0, 0
  li t0, 2
  csrw mideleg, t0
  li t0, 0xa
  csrw mie, t0
  ENTER_MODE(1, smode)
smode:
  la t0, strap
  csrw stvec, t0
  li t2, 0x02000000
  li t0, 1
  sw t0, 0(t2)
sloopA:
  j sloopA
sA_done:
  ecall
sB:
  li t0, 2
  csrs sstatus, t0
sloopB:
  j sloopB
