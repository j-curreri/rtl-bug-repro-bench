#include "test.h"
  .text
  .globl test_main
  .globl trap_handler
  .option norvc

test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li s9, 0x02000000          # CLINT msip
  li s8, 0x02004000          # mtimecmp
  li s7, 0x0200bff8          # mtime
  li s6, 0                   # interrupt count
  li t0, 0x2000
  csrs mstatus, t0
  li t0, 8
  csrw mie, t0               # MSIE

#define SW_BEGIN li t0, 1; sw t0, 0(s9); csrsi mstatus, 8
#define SW_END csrci mstatus, 8

  # varied instruction mixes at the interruption point
  SW_BEGIN; nop; nop; nop; nop; SW_END
  SW_BEGIN; addi a1, a1, 1; addi a2, a2, 2; add a3, a1, a2; SW_END
  SW_BEGIN; la a4, scratch; ld a5, 0(a4); sd a5, 8(a4); lw a5, 0(a4); SW_END
  SW_BEGIN; li a1, 7; li a2, 9; mul a3, a1, a2; div a3, a3, a1; SW_END
  SW_BEGIN; csrr a1, mscratch; csrw mscratch, a1; fence; fence.i; SW_END
  SW_BEGIN; lui a1, 0xfffff; xori a1, a1, -1; slli a1, a1, 3; SW_END
  SW_BEGIN; fmv.d.x ft0, a1; fadd.d ft1, ft0, ft0; SW_END
  .option rvc
  SW_BEGIN; c.nop; c.nop; c.li a1, 5; c.addi a1, 3; c.nop; SW_END
  .option norvc

  # timer interrupt
  li t0, 0x80
  csrw mie, t0
  ld t1, 0(s7)
  addi t1, t1, 20
  sd t1, 0(s8)
  csrsi mstatus, 8
  li t2, 20000
1: addi t2, t2, -1
  bnez t2, 1b
  csrci mstatus, 8

  PASS

  .align 4
trap_handler:
  csrr s10, mcause
  bgez s10, bad
  csrr s11, mtval
  bnez s11, bad
  sw zero, 0(s9)
  li s10, -1
  sd s10, 0(s8)
  addi s6, s6, 1
  mret
bad:
  FAIL(1)

  .data
  .align 4
scratch: .dword 0x1234, 0
