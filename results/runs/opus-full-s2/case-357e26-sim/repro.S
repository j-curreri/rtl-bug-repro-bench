#include "test.h"

/* Bug: PMP TOR matching uses the raw pmpaddr value, ignoring the G=1 grain.
 *
 * This core has PMP grain G=1 (8-byte grain). Per the RISC-V spec, when A=TOR
 * and G>=1, pmpaddr[0] reads as 0, i.e. the TOR boundary is forced to an
 * 8-byte-aligned address. The buggy core only applies this masking on CSR
 * *reads*; the address fed to the TOR comparator is the unmasked stored value.
 * Writing a pmpaddr whose lsb is set therefore places the buggy core's TOR
 * boundary 4 bytes (= 1<<2) above the spec-correct, grain-aligned boundary.
 *
 * Setup (lowest matching PMP entry wins):
 *   entry0: OFF      -> only supplies the lower TOR bound   pmpaddr0 = 0x80010000>>2
 *   entry1: TOR, --- -> protected region, no U-mode access  pmpaddr1 = (0x80012000>>2)|1
 *   entry2: NAPOT RWX over all memory (catch-all)           pmpaddr2 = all ones
 *
 *   Correct core: TOR top = 0x80012000 (lsb masked). A U-mode load from
 *   0x80012000 is NOT < top, so entry1 does not match; entry2 grants RWX ->
 *   the load succeeds -> PASS.
 *
 *   Buggy core:   TOR top = 0x80012004 (lsb kept). The load from 0x80012000
 *   is inside [0x80010000, 0x80012004), so entry1 matches with no permissions
 *   -> U-mode load access fault -> FAIL.
 */

#define TARGET   0x80012000      /* grain-aligned correct boundary; load address */

  .section .text
  .globl test_main
test_main:
  /* --- Program PMP --- */
  li    t0, (0x80010000 >> 2)      /* entry0: lower TOR bound */
  csrw  pmpaddr0, t0
  li    t0, ((0x80012000 >> 2) | 1)/* entry1: upper TOR bound, lsb set */
  csrw  pmpaddr1, t0
  li    t0, -1                     /* entry2: NAPOT match-all */
  csrw  pmpaddr2, t0

  /* pmpcfg0: byte0=0x00 (OFF), byte1=0x08 (TOR, no RWX), byte2=0x1F (NAPOT RWX) */
  li    t0, 0x001F0800
  csrw  pmpcfg0, t0

  /* --- Place a known value at the target so the correct-core load has data --- */
  li    t0, TARGET
  li    t1, 0x1234
  sd    t1, 0(t0)
  fence

  /* --- Enter U-mode and attempt the boundary load --- */
  ENTER_MODE(0, u_entry)

  .align 2
u_entry:
  li    t0, TARGET
  ld    a1, 0(t0)                  /* traps on buggy core; succeeds on correct */
  ecall                            /* signal success back to M-mode */
1: j 1b

  /* --- M-mode trap handler --- */
  .globl trap_handler
  .align 2
trap_handler:
  csrr  t6, mcause
  li    t5, 8                      /* ecall from U-mode: the load succeeded */
  beq   t6, t5, pass_case
  li    t5, 5                      /* load access fault: buggy core */
  beq   t6, t5, fail_case
  FAIL(127)                        /* any other unexpected trap */

pass_case:
  PASS
fail_case:
  FAIL(1)
