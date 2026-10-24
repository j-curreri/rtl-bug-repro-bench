#include "test.h"

  /* SXL reproducer for the cv64a6_imafdc_mu configuration.
   *
   * The SXL field of mstatus (bits 35:34) indicates the XLEN of the
   * supervisor execution environment.  The RISC-V privileged spec
   * defines exactly two valid encodings:  0 = RV32,  1 = RV64.
   * Encodings 2 and 3 are reserved.
   *
   * The core under test is RV64 (IS_XLEN64), so a conforming core must
   * read SXL as 0 or 1.  The buggy RTL instead drives SXL from the
   * XLEN_64 enum value (csr_regfile.sv: mstatus_d.sxl = riscv::XLEN_64,
   * which is 2'b10), so SXL reads back the reserved value 2.
   *
   * UXL (bits 33:32) uses a different encoding (1 = RV32, 2 = RV64), so
   * UXL reading 2 is correct on this core; only SXL is in error.
   *
   * This program reads SXL and FAILs if it holds a reserved value.  It
   * PASSes on a spec-correct core (SXL = 0 or 1) and FAILs on the buggy
   * core (SXL = 2). */

  .section .text
  .globl test_main
test_main:
  csrr t0, mstatus
  li   t1, 34
  srl  t2, t0, t1      # t2 = mstatus >> 34
  andi t2, t2, 3       # t2 = SXL (bits 35:34)
  li   t3, 2
  bltu t2, t3, ok      # SXL in {0,1} is a valid encoding
  FAIL(1)
ok:
  PASS

  .globl trap_handler
  .align 2
trap_handler:
  csrr a0, mcause
  slli a0, a0, 1
  ori  a0, a0, 1
  j _halt
