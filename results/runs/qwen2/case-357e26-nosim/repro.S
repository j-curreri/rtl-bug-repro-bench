/* PMP reproducer for CVA6 (cv64a6_imafdc_sv39).
 *
 * Bug: a TOR PMP entry does not protect the expected address range when
 * software writes a pmpaddr value whose lowest bit is set. This core only
 * supports a PMP grain of 8 bytes (G=1, see csr_regfile.sv: pmpaddr bit 0 is
 * not an address bit and reads back as 0 in TOR mode), so the top of a TOR
 * entry must be (pmpaddr & ~1) << 2. The buggy core computes pmpaddr << 2,
 * extending the region by 4 bytes when pmpaddr is odd; a U-mode access just
 * at the region boundary is then checked against the wrong entry.
 *
 * Test setup (M-mode sets up PMP; M-mode bypasses PMP unless locked):
 *   entry 0: OFF
 *   entry 1: TOR [0, pmpaddr1),  pmpaddr1 = 0x20000401 (odd), permissions = 0
 *   entry 2: TOR [pmpaddr1, pmpaddr2), pmpaddr2 = 0x20002000, permissions = RWX
 *
 * entry 1 top:
 *   correct: (0x20000401 & ~1) << 2 = 0x80001000
 *   buggy:   0x20000401 << 2        = 0x80001004
 *
 * entry 2 covers .tohost (0x80001000), .text (0x80002000) and the stack,
 * so all U-mode fetches/stores succeed on both cores and the only access that
 * discriminates is the U-mode load from 0x80001000 (the .tohost word, which
 * is initialized to 0 by the ELF):
 *   - correct core: load matches entry 2 (RWX) -> succeeds -> ecall -> PASS
 *   - buggy core:   load matches entry 1 (no permissions) -> load access
 *     fault -> trap -> FAIL
 */
#include "test.h"

  .section .text
  .balign 4
  .globl test_main
test_main:
  /* PMP configuration */

  /* entry 1: odd top address - the bug trigger */
  li   t0, 0x20000401
  csrw pmpaddr1, t0

  /* entry 2: even top address, covers the whole program + stack */
  li   t0, 0x20002000
  csrw pmpaddr2, t0

  /* pmpcfg0: entry2 = TOR|RWX, entry1 = TOR|no permissions, entry0 = OFF */
  li   t0, 0x000f0400
  csrw pmpcfg0, t0

  /* sanity-check the configuration */
  csrr t0, pmpaddr1
  li   t1, 0x20000400          /* bit0 of pmpaddr reads back as 0 in TOR */
  bne  t0, t1, setup_fail
  csrr t0, pmpcfg0
  li   t1, 0x000f0400
  bne  t0, t1, setup_fail

  /* drop to U-mode; returns to M-mode via ecall, handled by trap_handler */
  ENTER_MODE(0, u_check)

  /* M-mode must never reach this point */
setup_fail:
  FAIL(4)

u_check:
  .balign 4
  /* PMP boundary test: load the .tohost word at 0x80001000.
   * Correct core: in entry 2 -> allowed. Buggy core: in entry 1 -> fault. */
  li   t0, 0x80001000
  ld   t1, 0(t0)
  li   t2, 0                 /* .tohost is initialized to 0 */
  beq  t1, t2, u_ok
  li   a5, 1                 /* wrong value observed */
  ecall
u_ok:
  li   a5, 0
  ecall

  /* Overrides the default (weak) handler: the ecall from U-mode is the
   * expected way back; any other trap means the test failed. */
  .globl trap_handler
  .balign 4
trap_handler:
  csrr t0, mcause
  li   t1, 8                 /* 8 = ecall from U-mode */
  bne  t0, t1, fail_trap
  beqz a5, pass             /* a5 carries the U-mode result */
  li   a0, ((6 << 1) | 1)   /* wrong data value */
  j    _halt
fail_trap:
  FAIL(127)
pass:
  PASS
