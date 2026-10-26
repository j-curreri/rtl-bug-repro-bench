#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* Software-pend a delegated supervisor interrupt in M-mode. */
  la t0, interrupt_handler
  csrw stvec, t0
  li t0, 2                    /* delegate supervisor software interrupt */
  csrw mideleg, t0
  csrw mip, t0                /* SSIP is software writable */
  csrw mie, t0                /* enable SSIE */
  li t0, (1 << 1)             /* enable SIE before entering S-mode */
  csrs mstatus, t0
  ENTER_MODE(1, interrupt_window)
interrupt_window:
  nop
  j interrupt_resume
interrupt_resume:
  /* If execution reaches here the pending interrupt was not taken. */
  FAIL(1)

  .align 2
interrupt_handler:
  /* Clear the level-triggered source before inspecting state. */
  csrw sip, zero

  csrr t1, scause
  li t2, 0x8000000000000001
  bne t1, t2, fail_cause

  /* S-mode interrupt entry saves SIE in SPIE and records SPP=S. */
  csrr t1, sstatus
  andi t2, t1, (1 << 1)
  bnez t2, fail_status
  andi t2, t1, (1 << 5)
  beqz t2, fail_status
  andi t2, t1, (1 << 8)
  srli t2, t2, 8
  li t3, 1
  bne t2, t3, fail_status

  /* The interrupted PC must identify the first S-mode instruction. */
  csrr t1, sepc
  la t2, interrupt_window
  bltu t1, t2, fail_epc
  la t2, interrupt_resume
  bgeu t1, t2, fail_epc

  csrr t1, stval
  bnez t1, fail_tval

  PASS
fail_cause:   FAIL(2)
fail_tval:    FAIL(3)
fail_status:  FAIL(4)
fail_epc:     FAIL(5)
