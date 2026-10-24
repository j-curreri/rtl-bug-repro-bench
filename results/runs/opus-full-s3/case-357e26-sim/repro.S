#include "test.h"

/* Bug: with PMP grain G=1 (8-byte), a TOR entry whose pmpaddr has bit 0 set
 * must treat that bit as 0 (upper boundary = pmpaddr<<2, 8-byte aligned).
 * The buggy core keeps the raw stored bit 0 in the TOR comparison, so its
 * upper boundary is 4 bytes higher than the spec-correct one.
 *
 * Layout of PMP entries (U-mode, no paging, physical addressing):
 *   entry0: OFF  -> only supplies the TOR lower bound for entry1
 *   entry1: TOR, no permissions (deny), upper bound pmpaddr1
 *   entry2: NAPOT all-ones -> allow RWX everywhere (catch-all)
 *
 * TEST_ADDR = 0x80020000 is exactly the spec-correct upper boundary of
 * entry1 (pmpaddr1 = (TEST_ADDR>>2)|1).  A U-mode load from TEST_ADDR:
 *   correct core: entry1 upper = 0x80020000, addr NOT < upper -> no match,
 *                 falls through to entry2 (allow) -> load succeeds -> PASS.
 *   buggy  core:  entry1 upper = 0x80020004, addr < upper -> match entry1,
 *                 which denies -> load access fault -> not PASS.
 */

  .equ TEST_ADDR, 0x80020000

  .section .text
  .globl test_main
test_main:
  /* entry0 OFF: pmpaddr0 = lower bound = (TEST_ADDR-8)>>2 (bit0 clear) */
  li   t0, (0x80020000 - 8) >> 2
  csrw pmpaddr0, t0
  /* entry1 TOR upper bound, with bit 0 set -> triggers the bug */
  li   t0, (0x80020000 >> 2) | 1
  csrw pmpaddr1, t0
  /* entry2 NAPOT all-ones: match everything */
  li   t0, -1
  csrw pmpaddr2, t0
  /* pmpcfg0: byte0=OFF(0x00), byte1=TOR deny(0x08), byte2=NAPOT RWX(0x1F) */
  li   t0, 0x001F0800
  csrw pmpcfg0, t0

  /* place a known value at TEST_ADDR (M-mode: PMP does not restrict it) */
  li   t1, TEST_ADDR
  li   t2, 0x1234
  sd   t2, 0(t1)

  /* drop to U-mode at u_code */
  ENTER_MODE(0, u_code)

u_code:
  li   t1, TEST_ADDR
  ld   t2, 0(t1)      /* buggy: load access fault; correct: succeeds */
  ecall               /* correct path: ecall-from-U -> trap -> PASS */

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li   t5, 8          /* environment call from U-mode */
  bne  t6, t5, 1f
  PASS
1:
  FAIL(1)
