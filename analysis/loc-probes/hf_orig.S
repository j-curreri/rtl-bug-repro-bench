#include "hyp.h"
.globl test_main
.globl trap_handler
.align 2
trap_handler:
  csrr s1, mcause
  csrr s5, mstatus
  srli s5, s5, 39
  andi s5, s5, 1
  addi s3, s3, 1
  csrr t0, mepc
  lhu t1, 0(t0)
  andi t1, t1, 3
  li t2, 3
  beq t1, t2, 1f
  addi t0, t0, 2
  j 2f
1: addi t0, t0, 4
2: csrw mepc, t0
  mret
#define T(cause, n, insn...) li s1, 0; insn; li a5, cause; beq s1, a5, 9f; slli a0, s1, 8; slli s5, s5, 16; or a0, a0, s5; ori a0, a0, (n<<1)|1; j _halt; 9:
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  li t0, 0x00400000 | 0x00100000
  csrs mstatus, t0
  li t0, 0x200000   # hstatus.VTSR
  csrs 0x600, t0
  li t0, 0x100000   # VTVM
  csrs 0x600, t0
  li t0, 0x400000   # VTW
  csrs 0x600, t0
  ENTER_VS(vsmode)
.align 2
vsmode:
  T(22, 5, hfence.vvma)
  T(22, 6, hfence.gvma)
  T(22, 7, hlv.b t0, (a0))
  T(2, 8, mret)
  T(22, 9, csrr t0, hstatus)
  T(2, 10, csrr t0, mstatus)
  T(10, 11, ecall)
  T(3, 12, ebreak)
  T(22, 13, csrr t0, 0x600)
  li a0, 1
  j _halt
