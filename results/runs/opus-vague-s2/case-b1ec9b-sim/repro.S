#include "test.h"

/* MRET to a privilege below M must clear mstatus.MPRV (priv spec). */
#define MSTATUS_MPRV (1 << 17)

.text
.global test_main
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  li t0, MSTATUS_MPRV
  csrs mstatus, t0
  ENTER_MODE(1, s_code)

s_code:
  ecall
  FAIL(2)

.global trap_handler
.align 2
trap_handler:
  csrr t1, mcause
  li t2, 9            /* ecall from S-mode */
  bne t1, t2, 1f
  csrr t1, mstatus
  li t2, MSTATUS_MPRV
  and t1, t1, t2
  bnez t1, 2f
  PASS
1:
  FAIL(3)
2:
  FAIL(1)
