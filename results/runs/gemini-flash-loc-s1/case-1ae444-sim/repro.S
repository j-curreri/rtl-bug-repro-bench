#include "test.h"

  .globl test_main
test_main:
  // Initialize menvcfg to 0 (clearing FIOM)
  csrw menvcfg, zero

  // Write senvcfg with FIOM = 1
  li t0, 1
  csrw senvcfg, t0

  // Under the RISC-V Privileged Architecture Specification:
  // menvcfg (0x30A) is a Machine-mode CSR, whereas senvcfg (0x10A) is a
  // Supervisor-mode CSR. Modifying senvcfg must never alter menvcfg.
  //
  // On this buggy CVA6 core (core/csr_regfile.sv), both CSRs share a single
  // internal flip-flop (fiom_q). Writing senvcfg.FIOM = 1 corrupts menvcfg.FIOM.
  // On a compliant core, menvcfg.FIOM remains 0.
  csrr t1, menvcfg
  andi t1, t1, 1
  bnez t1, fail

  PASS

fail:
  FAIL(1)
