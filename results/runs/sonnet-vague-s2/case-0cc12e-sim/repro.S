#include "hyp.h"
.option norvc
.globl test_main
.globl trap_handler
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  la t0, shandler
  li t1, 0x40000000
  sub t0, t0, t1
  csrw stvec, t0
  li t0, 0xb7ff
  csrw medeleg, t0
  li t0, 0x6000
  csrs mstatus, t0
  li t0, 0x80000000
  srli t0, t0, 2
  li t1, 0x1fffff
  or t0, t0, t1
  csrw pmpaddr0, t0
  li t0, 0x1f
  csrw pmpcfg0, t0
  GIGA_LEAF(vs_root, 2, 0x80000000, (PTE_V|PTE_R|PTE_W|PTE_X|PTE_A|PTE_D|PTE_U))
  GIGA_LEAF(vs_root, 1, 0x80000000, (PTE_V|PTE_R|PTE_W|PTE_X|PTE_A|PTE_D))
  GIGA_LEAF(vs_root, 3, 0xC0000000, (PTE_V|PTE_R|PTE_A|PTE_U))
  GIGA_LEAF(vs_root, 4, 0x100000000, (PTE_V|PTE_R|PTE_W|PTE_A|PTE_D|PTE_U))
  la t0, vs_root
  srli t0, t0, 12
  li t1, SATP_SV39
  or t0, t0, t1
  csrw satp, t0
  sfence.vma
  ENTER_MODE(0, umode)
umode:
  li s1, 1
  li s7, 5
  li s2, 0x100000008
  lw x0, 0(s2)
  li s1, 2
  li s7, 7
  sw x0, 0(s2)
  li s1, 3
  li s7, 13
  li s2, 0x2000
  lw x0, 0(s2)
  li s1, 4
  li s7, 15
  li s2, 0xC0000010
  sw x0, 0(s2)
  li s1, 5
  li s7, 12
  li s2, 0x1000
  jalr x0, 0(s2)
r5:
  li s1, 6
  li s2, 0xC0000040
  jalr x0, 0(s2)
r6:
  li s1, 7
  li s7, 4
  li s2, 0x80001001
  fld f0, 0(s2)
  li s1, 8
  li s7, 6
  sw x0, 0(s2)
  li s1, 9
  li s7, 1
  li s2, 0x100000040
  jalr x0, 0(s2)
r9:
  li a0, 1
  j _halt
.align 2
trap_handler:
  csrr s3, mcause
  slli a0, s3, 8
  add a0, a0, s1
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt
.align 2
shandler:
  csrr s3, scause
  csrr s4, stval
  csrr s5, sepc
  csrr s6, sstatus
  bne s3, s7, bad
  bne s4, s2, bad
  andi t0, s6, 0x100
  bnez t0, bad
  li t0, 5
  bge s1, t0, fetchy
  bne s5, s2, nn
nn:
  addi s5, s5, 4
  csrw sepc, s5
  sret
fetchy:
  li t0, 7
  bge s1, t0, nofetch
  bne s5, s2, bad
  la t2, r5
  li t0, 5
  beq s1, t0, f
  la t2, r6
f:
  csrw sepc, t2
  sret
nofetch:
  li t0, 9
  blt s1, t0, nn
  bne s5, s2, bad
  la t2, r9
  j f
bad:
  slli a0, s1, 4
  add a0, a0, s3
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt
HYP_TABLES
