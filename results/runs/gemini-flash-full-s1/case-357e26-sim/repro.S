#include "test.h"

/*
 * Bug reproducer: PMP TOR mode address range with grain G=1 (8 bytes)
 *
 * In RISC-V specifications, when PMP granularity is 8 bytes (G=1),
 * TOR address matching requires 8-byte alignment (pmpaddr[0] is WARL and
 * treated as 0).
 * On this buggy core, writing pmpaddr with bit 0 set causes the TOR
 * upper bound to be computed as ((pmpaddr << 2) | 4) instead of masking
 * bit 0. Consequently:
 * - On a compliant core:
 *     Entry 1 covers [dummy_protected, boundary_target) with NONE permissions.
 *     Entry 2 covers [boundary_target, -1) with RWX permissions.
 *     A U-mode access at boundary_target matches Entry 2 (RWX), succeeds,
 *     and ends with PASS.
 * - On this buggy core:
 *     Entry 1 incorrectly extends to [dummy_protected, boundary_target + 4).
 *     A U-mode access at boundary_target matches Entry 1 (NONE), triggers
 *     an unexpected load access fault, and terminates with FAIL.
 */

.globl test_main
test_main:
  /* Entry 0: [0, dummy_protected) -> RWX (for code execution, stack, tohost) */
  la t0, dummy_protected
  srli t0, t0, 2
  csrw pmpaddr0, t0

  /* Entry 2: [boundary_target, -1) -> RWX */
  li t0, -1
  csrw pmpaddr2, t0

  /* Configure pmpcfg0:
   * Entry 0: TOR (0x08) | RWX (0x07)  = 0x0f
   * Entry 1: TOR (0x08) | NONE (0x00) = 0x08
   * Entry 2: TOR (0x08) | RWX (0x07)  = 0x0f
   */
  li t0, 0x0f080f
  csrw pmpcfg0, t0

  /* Write pmpaddr1 with lowest bit set */
  la t0, boundary_target
  srli t0, t0, 2
  ori  t0, t0, 1
  csrw pmpaddr1, t0

  /* Rewrite pmpcfg0 to ensure configuration applies regardless of CSR write ordering */
  li t0, 0x0f080f
  csrw pmpcfg0, t0

  /* Enter U-mode */
  ENTER_MODE(0, u_mode)

u_mode:
  /* Access exactly at the region boundary */
  la t0, boundary_target
  lw t1, 0(t0)

  /* On a compliant core, access succeeds and execution reaches PASS */
  PASS

.section .data
.balign 8
dummy_protected:
  .dword 0x0123456789abcdef

.balign 8
boundary_target:
  .dword 0xfedcba9876543210
