#include "test.h"

/* Sdtrig mcontrol6 NAPOT (match=1) address matching.
 * tdata2 = base | 0b0111 describes the 16-byte NAPOT range [base, base+16).
 * A load from base+8 must fire the trigger (breakpoint exception, mcause 3). */

#define MC6_LOAD_EQ    ((6 << 60) | (0 << 7) | (1 << 6) | 1)
#define MC6_LOAD_NAPOT ((6 << 60) | (1 << 7) | (1 << 6) | 1)

  .text
  .option norvc
  .globl test_main
test_main:
  csrw tselect, zero

  /* 1: sanity check, equal match on the exact address */
  li s1, 0
  la t0, buf
  addi t0, t0, 8
  csrw tdata2, t0
  li t1, MC6_LOAD_EQ
  csrw tdata1, t1
  ld t2, 0(t0)
  csrw tdata1, zero
  li t3, 1
  bne s1, t3, fail1

  /* 2: NAPOT match, 16-byte range, access at offset 8 */
  li s1, 0
  la t0, buf
  ori t1, t0, 7
  csrw tdata2, t1
  li t1, MC6_LOAD_NAPOT
  csrw tdata1, t1
  csrr t3, tdata1
  li t4, (0xF << 60) | (0xF << 7)
  and t3, t3, t4
  li t4, (6 << 60) | (1 << 7)
  bne t3, t4, fail3
  ld t2, 8(t0)
  csrw tdata1, zero
  li t3, 1
  bne s1, t3, fail2

  /* 3: NAPOT match, access at offset 0 */
  li s1, 0
  la t0, buf
  ori t1, t0, 7
  csrw tdata2, t1
  li t1, MC6_LOAD_NAPOT
  csrw tdata1, t1
  ld t2, 0(t0)
  csrw tdata1, zero
  li t3, 1
  bne s1, t3, fail4

  PASS
fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)
fail4: FAIL(4)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t5, mcause
  li t6, 3
  bne t5, t6, bad_trap
  csrw tdata1, zero
  addi s1, s1, 1
  csrr t5, mepc
  addi t5, t5, 4
  csrw mepc, t5
  mret
bad_trap:
  FAIL(5)

  .data
  .align 6
buf:
  .dword 0x1111, 0x2222, 0x3333, 0x4444
