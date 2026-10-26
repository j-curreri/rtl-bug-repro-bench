#include "test.h"

/*
 * RV64 mstatus.SXL (bits 35:34) must be read-only zero when S-mode
 * is not implemented (Privileged ISA, "Base ISA Control in mstatus").
 * This configuration implements M and U, but not S.
 *
 * csr_regfile.sv unconditionally assigns XLEN_64 to mstatus_d.sxl
 * whenever IS_XLEN64 is true.  The sxl member of mstatus_rv_t in
 * riscv_pkg.sv occupies bits 35:34, so the erroneous value is visible
 * through an ordinary M-mode CSR read.
 */

    .section .text
    .balign 4
    .globl test_main
test_main:
    /* Check the configuration prerequisite: misa.S must be clear. */
    csrr t0, misa
    li t1, (1 << 18)
    and t0, t0, t1
    bnez t0, wrong_configuration

    li t1, (3 << 34)

    /* Neither clearing nor setting a read-only-zero field may change it. */
    csrc mstatus, t1
    csrr t0, mstatus
    and t0, t0, t1
    bnez t0, bad_sxl

    csrs mstatus, t1
    csrr t0, mstatus
    and t0, t0, t1
    bnez t0, bad_sxl

    PASS

bad_sxl:
    FAIL(1)
wrong_configuration:
    FAIL(2)

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t6, mcause
    FAIL(3)
