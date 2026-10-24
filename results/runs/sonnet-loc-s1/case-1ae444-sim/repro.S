#include "test.h"
.option norvc
.globl test_main
.globl trap_handler
.macro EXP n, reg, ev
  li t3, \ev
  beq \reg, t3, 9f
  mv a0, \reg
  slli a0, a0, 8
  ori a0, a0, \n
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt
9:
.endm
.align 2
trap_handler:
  csrr s2, mcause
  csrr s3, mepc
  csrr s4, mtval
  addi s3, s3, 4
  csrw mepc, s3
  # return to M-mode after trap? set mpp to M if caller asked (s7)
  beqz s7, 1f
  li t5, 0x1800
  csrs mstatus, t5
1:
  mret
.align 12
root:
  .dword 0x00000000000000cf | 0   # placeholder
  .dword 0
  .dword 0
  .dword 0
  .space 4096-32
.align 3
dat: .dword 0x1122334455667788
.text
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  # build root: vpn2 index: 0 -> PA 0x80000000 X only (V|X|A) ; 1 -> PA 0x80000000 RWX U ; 2 -> identity RWX S ; 3 -> PA 0x80000000 RW S
  la t0, root
  li t1, (0x80000000 >> 12) << 10
  li t2, 0x49          # V | X | A
  or t2, t1, t2
  sd t2, 0(t0)
  li t2, 0xdf          # V R W X? compute: V1 R2 W4 X8 U16 A64 D128 = 0xdf
  or t2, t1, t2
  sd t2, 8(t0)
  li t2, 0xcf          # V R W X A D
  or t2, t1, t2
  sd t2, 16(t0)
  li t2, 0xc7          # V R W A D
  or t2, t1, t2
  sd t2, 24(t0)
  srli t0, t0, 12
  li t1, 8
  slli t1, t1, 60
  or t0, t0, t1
  csrw satp, t0
  sfence.vma
  la s0, dat
  li s1, 0x80000000
  sub s0, s0, s1          # offset of dat
  # enter S mode
  li s7, 1
  ENTER_MODE(1, scode)
.align 2
scode:
  # (a) SUM=0 load via U page alias (VA 0x40000000)
  li s2, 0
  li t1, 0x40000000
  add t1, t1, s0
  ld t2, 0(t1)
  EXP 1, s2, 13
  # (b) SUM=1
  li t0, 0x40000
  csrs sstatus, t0
  li s2, 0
  ld t2, 0(t1)
  EXP 2, s2, 0
  li t3, 0x1122334455667788
  EXP 3, t2, 0x1122334455667788
  # (c) MXR: X-only page at VA 0
  li s2, 0
  add t1, zero, s0
  ld t2, 0(t1)
  EXP 4, s2, 13
  li t0, 0x80000
  csrs sstatus, t0
  li s2, 0
  ld t2, 0(t1)
  EXP 5, s2, 0
  EXP 6, t2, 0x1122334455667788
  # clear sum: store to U page should fault? skip
  li t0, 0x40000
  csrc sstatus, t0
  li s2, 0
  ld t2, 0(t1)    # still X-only via MXR ok
  EXP 7, s2, 0
  ecall
