#include "test.h"

/* Sdtrig mcontrol6 address-match triggers (match=equal, M-mode, action=breakpoint):
 * each must raise a breakpoint (mcause 3) before the matched access completes.
 * On the buggy core the load-address trigger never fires: the load hangs. */

  .section .data
  .align 3
g_cause: .dword 0
buf:     .dword 0x5555

  .section .text
  .globl test_main
test_main:
  # ---- Test 1: execute address trigger on an instruction fetch ----
  la t0, tgt_exec
  csrw tdata2, t0
  li t0, 0x6000000000000044        # type=6, m=1, execute=1, match=equal, action=breakpoint
  csrw tdata1, t0
  la s11, ret_exec
  li s10, 1
  la t0, g_cause
  sd zero, 0(t0)
  j tgt_exec
ret_exec:
  csrw tdata1, zero
  li s10, 0
  la t0, g_cause
  ld t1, 0(t0)
  li t2, 3
  bne t1, t2, fail1
  # ---- Test 2: store address trigger ----
  la t0, buf
  csrw tdata2, t0
  li t0, 0x6000000000000042        # type=6, m=1, store=1, match=equal, action=breakpoint
  csrw tdata1, t0
  la t0, g_cause
  sd zero, 0(t0)
  la t0, buf
  li t1, 0x1234
  sd t1, 0(t0)                     # must trap before the store is performed
  csrw tdata1, zero
  la t0, g_cause
  ld t1, 0(t0)
  li t2, 3
  bne t1, t2, fail2
  la t0, buf
  ld t1, 0(t0)
  li t2, 0x5555
  bne t1, t2, fail2
  # ---- Test 3: load address trigger ----
  la t0, buf
  csrw tdata2, t0
  li t0, 0x6000000000000041        # type=6, m=1, load=1, match=equal, action=breakpoint
  csrw tdata1, t0
  la t0, g_cause
  sd zero, 0(t0)
  la t0, buf
  ld t1, 0(t0)                     # must trap
  csrw tdata1, zero
  la t0, g_cause
  ld t1, 0(t0)
  li t2, 3
  bne t1, t2, fail3
  PASS

tgt_exec:
  j ret_exec

fail1:
  FAIL(1)
fail2:
  FAIL(2)
fail3:
  FAIL(3)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  la t1, g_cause
  sd t0, 0(t1)
  bnez s10, 1f
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
1:
  csrw mepc, s11
  mret
