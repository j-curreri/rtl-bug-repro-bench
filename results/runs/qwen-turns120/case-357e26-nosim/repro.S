/* PMP TOR-boundary reproducer.
 *
 * Bug: a PMP entry in TOR mode does not protect the expected address range
 * when software writes a pmpaddr whose lowest bit is set.  This core's PMP
 * grain is 8 bytes (G=1), so a spec-conformant core must ignore pmpaddr's
 * lowest bit in TOR mode (it is a reserved WARL bit that reads back as 0).
 * The buggy core instead uses the raw value, shifting the entry boundary by
 * 4 bytes, so a U-mode access just at the boundary is checked against the
 * wrong entry.
 *
 * M-mode setup:
 *   pmpaddr0 = 0x20000003   (lowest bit SET)
 *   pmpaddr1 = 0x20004000
 *   pmpcfg0  = 0x0f08
 *     entry 0 = 0x08 : TOR, no U-mode permissions   -> [0,     top0)
 *     entry 1 = 0x0f : TOR, U-mode RWX              -> [top0,  top1)
 *
 * The entry 0 / entry 1 boundary (top0):
 *   spec-correct : (pmpaddr0 & ~1) << 2 = 0x80000008
 *   buggy        :  pmpaddr0        << 2 = 0x8000000C
 *
 * A U-mode load to 0x80000008 (the spec-correct start of entry 1):
 *   correct core -> address is in entry 1 (RWX) -> access allowed
 *   buggy   core -> address is in entry 0 (none) -> load access fault
 *
 * On the correct core the load succeeds and the program ecall's back to
 * M-mode (mcause == 8, ENV_CALL_UMODE) and PASSes.  On the buggy core the
 * load faults (mcause == 5, LD_ACCESS_FAULT) and the program FAILs.
 */
#include "test.h"

  .section .text
  .globl test_main

test_main:
  /* --- PMP setup (M-mode; M is unrestricted by non-locked PMP entries) --- */
  li   t0, 0x20000003
  csrw pmpaddr0, t0

  li   t0, 0x20004000
  csrw pmpaddr1, t0

  /* pmpcfg0: byte0 (entry 0) = 0x08, byte1 (entry 1) = 0x0f. */
  li   t0, 0x0f08
  csrw pmpcfg0, t0

  /* Drop to U-mode at u_entry. */
  ENTER_MODE(0, u_entry)

u_entry:
  /* --- U-mode: the boundary load -------------------------------------- */
  li   t0, 0x80000008
  ld   t1, 0(t0)            /* faults on the buggy core */

  /* Reached only when the load succeeded (correct core): trap to M-mode. */
  ecall

  /* Override the weak default handler from crt.S. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li   t0, 8                /* ENV_CALL_UMODE: expected success path */
  bne  t6, t0, 1f
  PASS
1:
  FAIL(127)
