/* Sdtrig mcontrol6 NAPOT (match=1) load-address trigger must fire for an
 * access inside the naturally aligned range.
 * Phase 1 (control): exact-match (match=0) trigger on buf+4 -> breakpoint expected.
 * Phase 2: NAPOT trigger tdata2 = buf | 7 (16-byte range buf..buf+15),
 *          load from buf+4 -> breakpoint expected. */
#include "test.h"

#define MC6_TYPE   (6 << 60)
#define MC6_NAPOT  (1 << 7)
#define MC6_U      (1 << 3)
#define MC6_LOAD   (1 << 0)

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  la a1, buf

  /* Phase 1: exact-match trigger on buf+4 */
  csrw tselect, zero
  csrw tdata1, zero
  addi t0, a1, 4
  csrw tdata2, t0
  li t0, (MC6_TYPE | MC6_U | MC6_LOAD)
  csrw tdata1, t0
  li s0, 1
  ENTER_MODE(0, u_load)

u_load:
  lw t1, 4(a1)
  ecall                 /* reached only if the trigger did not fire */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t3, mcause
  li t4, 3
  bne t3, t4, no_bkpt
  li t4, 1
  bne s0, t4, phase2_hit

  /* Phase 1 fired: reprogram trigger 0 as NAPOT over buf..buf+15 */
  csrw tdata1, zero
  ori t0, a1, 7
  csrw tdata2, t0
  li t0, (MC6_TYPE | MC6_NAPOT | MC6_U | MC6_LOAD)
  csrw tdata1, t0
  li s0, 2
  ENTER_MODE(0, u_load)

phase2_hit:
  csrw tdata1, zero
  PASS

no_bkpt:
  li t4, 8
  bne t3, t4, unexpected
  li t4, 1
  beq s0, t4, fail1
  FAIL(2)               /* NAPOT trigger did not fire */
fail1:
  FAIL(1)               /* exact trigger did not fire (setup problem) */
unexpected:
  FAIL(3)

  .data
  .align 4
buf:
  .dword 0x1111111111111111
  .dword 0x2222222222222222
