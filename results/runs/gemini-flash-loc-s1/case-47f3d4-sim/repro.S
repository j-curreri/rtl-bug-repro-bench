/*
 * Reproducer for CVA6 deviation from RISC-V Privileged Architecture.
 *
 * Specification: RISC-V Privileged Architecture, Section 3.1.6.2:
 * "When S-mode is not supported, SXL is read-only zero."
 *
 * In configuration cv64a6_imafdc_mu, S-mode is not supported (RVS = 0).
 * Therefore, mstatus.SXL (bits 35:34) must be read-only zero.
 *
 * On the buggy core (core/csr_regfile.sv and core/include/riscv_pkg.sv),
 * mstatus.SXL is hardwired to 2 (XLEN_64).
 */

#include "test.h"

.globl test_main
test_main:
    // Read mstatus
    csrr a0, mstatus

    // Extract SXL (bits 35:34)
    li t0, 3
    slli t0, t0, 34
    and a0, a0, t0

    // On a correct core without S-mode, SXL must be zero.
    // On the buggy core, SXL is 2 (non-zero).
    bnez a0, bug_detected

    PASS

bug_detected:
    FAIL(1)
