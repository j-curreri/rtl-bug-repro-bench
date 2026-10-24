#include "harness/hyp.h"
.global test_main
.global trap_handler
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  la s0, log
  ENTER_VS(vs_code)
.align 2
vs_code:
  ecall                 # case0
  ebreak                # case1
  .word 0xffffffff      # case2 illegal
  csrr t0, hstatus      # case3 virtual instr
  li t2, 0x1000
  ld t3, 0(t2)          # case4 load guest page fault
  li t2, 0x80000001
  ld t3, 0(t2)          # case5 misaligned (maybe)
  li a0, 0
  ecall                 # done
.align 2
trap_handler:
  csrr t0, mcause
  csrr t1, mstatus
  sd t0, 0(s0)
  sd t1, 8(s0)
  csrr t0, mtval
  csrr t1, mtval2
  sd t0, 16(s0)
  sd t1, 24(s0)
  csrr t0, mtinst
  sd t0, 32(s0)
  addi s0, s0, 40
  la t0, logend
  bgeu s0, t0, check
  csrr t0, mcause
  li t1, 10
  bne t0, t1, adv
  # ecall: advance; stop after 6th trap
  la t1, log
  addi t1, t1, 240
  bgeu s0, t1, check
adv:
  csrr t0, mepc
  lhu t1, 0(t0)
  andi t1, t1, 3
  addi t1, t1, -3
  seqz t1, t1
  slli t1, t1, 1
  addi t0, t0, -2
  add t0, t0, t1
  addi t0, t0, 4
  csrw mepc, t0
  mret
check:
  # per entry: mstatus bits MPV(39) GVA(38) must be: ecall MPV1 GVA0 ; ebreak 1,1 ; illegal 1,0 ; virt 1,0; gpf 1,1
  la s1, log
  # case0 ecall
  ld t1, 8(s1);  srli t1,t1,38; andi t1,t1,3; li t2,2; bne t1,t2,f1
  # case1 ebreak
  ld t1, 48(s1); srli t1,t1,38; andi t1,t1,3; li t2,3; bne t1,t2,f4
  # case2 illegal
  ld t1, 88(s1); srli t1,t1,38; andi t1,t1,3; li t2,2; bne t1,t2,f7
  # case3 virtual
  # case4 gpf
  PASS
f1: FAIL(1)
f2: FAIL(2)
f3: FAIL(3)
f4: FAIL(4)
f5: FAIL(5)
f6: FAIL(6)
f7: FAIL(7)
f8: FAIL(8)
f9: FAIL(9)
f10: FAIL(10)
f11: FAIL(11)
f12: FAIL(12)
f13: FAIL(13)
.data
.align 3
log: .space 400
logend:
HYP_TABLES
