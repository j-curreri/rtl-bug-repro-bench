#include "test.h"

/*
 * PMP TOR top-of-range bug reproducer (CVA6, cv64a6_imafdc_sv39, PMP grain 8 bytes).
 *
 * Setup (M-mode):
 *   PMP entry 0: TOR [0x0000_0000, 0x8000_40000), RWX  - covers the whole program
 *                (pmpaddr0 = 0x8000_40000 / 4 = 0x2000_10000).
 *   PMP entry 1: TOR [0x8000_40000, 0x8000_40008], RWX
 *                pmpaddr1 = 0x8000_40008 / 4 = 0x2000_10002: bit 1 (the LSD, the
 *                least significant address digit of this 8-byte-grain PMP) is set
 *                and bit 0 is clear.
 *
 * Per the RISC-V PMP specification, when the LSD of the top pmpaddr of a TOR
 * entry is set, the top address itself is *inside* the protected region.  So a
 * U-mode access to 0x8000_40008 must match entry 1.
 *
 * - Correct core: the U-mode load of that boundary byte succeeds; the following
 *   ecall traps into M-mode with mcause 8 (ECALL from U-mode) -> PASS.
 * - Buggy core: the TOR top is treated as unconditionally exclusive, so no PMP
 *   entry matches 0x8000_40008; the U-mode load raises a load access fault
 *   (mcause 5) -> FAIL.
 */

  .globl test_main
test_main:
  li t0, 0x200010000           /* pmpaddr0 = 0x8000_40000 / 4 */
  csrw pmpaddr0, t0
  li t0, 0x200010002           /* pmpaddr1 = 0x8000_40008 / 4, LSD (bit 1) set */
  csrw pmpaddr1, t0
  li t0, 0x1f1f                /* entry 0: RWX, entry 1: RWX, entries 2..7: OFF */
  csrw pmpcfg0, t0

  /* enter U-mode at u_test */
  ENTER_MODE(0, u_test)

m_done:
  /* mcause checked in trap_handler: the boundary load succeeded */
  PASS

  .align 2
u_test:
  li t1, 0x800040008           /* the byte at the top of PMP entry 1 */
  lbu t0, 0(t1)               /* allowed on a spec-compliant core;
                                  load access fault on the buggy core */
  ecall                       /* to M-mode with mcause = 8 */
1: j 1b

  .align 2
.globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 8                    /* U-mode ECALL: boundary load went through */
  beq t0, t1, m_done
  /* diagnostic: report mcause as the tohost code */
  slli a0, t0, 1
  ori a0, a0, 1
  j _halt
