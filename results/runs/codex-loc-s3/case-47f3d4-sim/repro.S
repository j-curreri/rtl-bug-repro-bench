#include "test.h"

/*
 * cv64a6_imafdc_mu implements M and U, but not S (CVA6Cfg.RVS = 0).
 * The privileged specification requires mstatus.SXL to be read-only zero
 * when S-mode is not supported. On RV64, SXL occupies bits 35:34.
 *
 * In csr_regfile.sv, csr_update unconditionally assigns XLEN_64 (2, as
 * defined in riscv_pkg.sv) to mstatus_d.sxl whenever IS_XLEN64 is true,
 * including this configuration. Consequently the supplied core fails
 * this test; a conforming implementation reads zero and reaches PASS.
 */
    .section .text
    .option norvc
    .globl test_main
test_main:
    csrr t0, mstatus
    srli t0, t0, 34
    andi t0, t0, 3
    bnez t0, bad_sxl
    PASS
bad_sxl:
    FAIL(1)

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t6, mcause
    FAIL(127)
