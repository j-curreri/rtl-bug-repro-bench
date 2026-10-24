#include "test.h"
.section .text
.globl test_main
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  # root[2] -> level1 table; level1[0] = S-only 2M megapage (code), level1[1] = U-only megapage
  la t1, root
  la t3, l1
  srli t2, t3, 12
  slli t2, t2, 10
  ori t2, t2, 1
  sd t2, 16(t1)
  li t2, ((0x80000000 >> 12) << 10) | 0xCF
  sd t2, 0(t3)
  li t2, ((0x80200000 >> 12) << 10) | 0xDF
  sd t2, 8(t3)
  srli t1, t1, 12
  li t2, (8 << 60)
  or t1, t1, t2
  mv s1, t1
  la t0, smode
  csrw mepc, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (1 << 11) | (1 << 17)   # MPP=S, MPRV=1
  csrs mstatus, t0
  mret
smode:
  csrw satp, s1
  sfence.vma
  ecall
  FAIL(1)
.balign 4
trap_handler:
  csrr t0, mcause
  li t1, 9
  bne t0, t1, bad
  li t2, 0x80200000
  ld t3, 0(t2)     # M-mode access: if MPRV stuck, U-page from S faults
  PASS
bad:
  FAIL(2)
.balign 4096
root: .space 4096
l1: .space 4096
