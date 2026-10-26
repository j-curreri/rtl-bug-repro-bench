#include "test.h"

/* Grant S/U modes access to DRAM and the CLINT. */
#define PMP_ALLOW_ALL           \
  li t0, -1;                    \
  csrw pmpaddr0, t0;            \
  li t0, 0x1f;                  \
  csrw pmpcfg0, t0

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  la t0, trap_handler
  csrw mtvec, t0

  /* Arrange a machine timer interrupt to wake a legal U-mode WFI. */
  li t0, 0x0200bff8            /* mtime */
  ld t1, 0(t0)
  li t2, 100000
  add t1, t1, t2
  li t0, 0x02004000            /* mtimecmp */
  sd t1, 0(t0)

  li t0, (1 << 7)              /* mie.MTIE */
  csrs mie, t0
  li t0, (1 << 3)              /* mstatus.MIE */
  csrs mstatus, t0

  ENTER_MODE(0, user_code)

user_code:
  wfi
  PASS

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 7                      /* machine timer interrupt */
  bne t0, t1, unexpected_trap

  /* Prevent another timer interrupt after returning to U-mode. */
  li t0, (1 << 7)
  csrc mie, t0
  mret

unexpected_trap:
  FAIL(10)
