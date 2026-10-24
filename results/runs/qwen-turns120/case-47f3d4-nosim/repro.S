#include "test.h"

/*
 * Bug reproduced:
 *   This core does not implement S-mode (CVA6ConfigRVS = 0), yet mstatus
 *   reports a non-zero S-mode XLEN (the SXL field). The RISC-V privileged
 *   spec requires the XLEN control field of an unimplemented privilege mode
 *   to be read-only zero.
 *
 *   In this core's 64-bit mstatus, the SXL field occupies bits [35:34].
 *   On a correct core SXL reads 0. On the buggy core SXL is forced to
 *   XLEN_64 (0b10), so mstatus bit 35 is set.
 *
 *   Note: we must check ONLY the SXL field [35:34], not the adjacent UXL
 *   field [33:32]. U-mode IS implemented (CVA6ConfigRVU = 1), so UXL is
 *   non-zero on a correct core as well and must not trigger a failure.
 *
 * Strategy: read mstatus, mask the SXL field [35:34].
 *   - SXL == 0   -> core is spec-conformant -> PASS
 *   - SXL != 0   -> core has the bug        -> FAIL(1)
 */
  .globl test_main
test_main:
  csrr  t0, mstatus
  li    t1, 0xc00000000      /* SXL mask: bits [35:34] */
  and   t0, t0, t1
  bnez  t0, 1f               /* SXL != 0 -> buggy core */
  PASS
1:
  FAIL(1)
