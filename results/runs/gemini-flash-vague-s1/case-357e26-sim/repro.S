#include "test.h"

/*
 * Reproducer for PMP address range protection bug:
 *
 * PMP entry 1 is configured with TOR covering [0x80010000, 0x80010004) with RW permissions (L=1).
 * PMP entry 2 is configured with TOR covering [0x80010004, 0x80010008) with NO permissions (L=1).
 *
 * An 8-byte load (ld) at address 0x80010000 accesses bytes in range [0x80010000, 0x80010008).
 * Bytes [0x80010004, 0x80010008) are protected by entry 2 (NO ACCESS, LOCKED).
 *
 * According to RISC-V Privileged Architecture Specification (Section 3.7.1):
 * "An access matches a PMP entry if all bytes of the access are within the range specified
 *  by the entry. If an access crosses a boundary between PMP regions, or between a PMP
 *  region and an unprotected region, and any byte of the access is not permitted, an
 *  access-fault exception must be raised."
 *
 * - On a core that is correct according to the RISC-V specifications:
 *   The 8-byte load raises a Load Access Fault (mcause = 5). The trap handler catches
 *   this expected fault and calls PASS.
 *
 * - On this buggy CVA6 core:
 *   The PMP check only evaluates the start byte (0x80010000), sees that it matches
 *   entry 1 (RW), and permits the load without checking bytes [0x80010004, 0x80010008).
 *   Thus, the load completes without trapping and executes FAIL(1).
 */

.globl trap_handler
.align 2
trap_handler:
  csrr t6, mcause
  li t1, 5 /* load access fault */
  beq t6, t1, pass
  FAIL(2)

pass:
  PASS

.globl test_main
test_main:
  /* Setup PMP registers in M-mode */
  li t0, (0x80010000 >> 2)
  csrw pmpaddr0, t0
  li t0, (0x80010004 >> 2)
  csrw pmpaddr1, t0
  li t0, (0x80010008 >> 2)
  csrw pmpaddr2, t0

  /*
   * pmpcfg0:
   * entry 0: 0x00 (OFF)
   * entry 1: 0x8b (L=1, TOR, RW)
   * entry 2: 0x88 (L=1, TOR, NO ACCESS)
   */
  li t0, (0x88 << 16) | (0x8b << 8) | 0x00
  csrw pmpcfg0, t0
  fence

  /* 8-byte load spanning across the PMP boundary into protected memory */
  li a0, 0x80010000
  ld t0, 0(a0)

  /* If the core fails to protect the range, execution reaches here */
  FAIL(1)
